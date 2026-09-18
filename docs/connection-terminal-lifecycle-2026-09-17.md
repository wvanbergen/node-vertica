# Connection shutdown: issue and resolution

GitHub issues are disabled for `protobi/node-vertica`, so this document records the issue locally. No upstream issue was submitted.

## Issue

A terminal connection failure must settle every outstanding operation exactly once, reject new work, and distinguish a shutdown request from confirmed transport closure. The driver owns this invariant because it owns the socket, protocol events, and query queue.

The previous implementation violated it in several ways:

- Socket close, error, and timeout handled the active query but left queued queries unresolved.
- The connect callback remained installed after successful initialization and could be called again on a later failure.
- Work could still be queued after shutdown.
- `disconnect()` checked the socket's nonexistent `connected` property, preventing the intended Terminate message.
- Repeated terminal events could complete a query more than once; queued queries also lacked the listeners that cleanup assumed existed.

These defects obstruct reliable pool disposal and recovery. They are not proof that this driver caused the reported 50-session exhaustion; pool allocation and renderer lifetimes require separate application fixes. Related work: [protobi-sql #1269](https://github.com/protobi/protobi-sql/issues/1269).

## Resolution

Implemented in local commit `29cca0b`:

- Track closing and closed states; reject work scheduled after shutdown.
- Fail active and queued queries, mark them terminal synchronously, and defer their user notifications. Ignore late completion events after termination.
- Clear the connect callback when initialization succeeds or fails.
- Send Terminate during graceful disconnect using the driver's connection state.
- Add `destroy(error)` to abort abandoned operations. The socket's `close` event confirms closure; calling `destroy()` alone does not.
- Make listener cleanup safe for queries that never started.

Changes belong in `src/connection.coffee` and `src/query.coffee`, with regenerated JavaScript in `lib/`. Callers should not emulate the driver's lifecycle handling.

## Validation and limits

`npm run test:unit` passes all 95 tests on Node 24, including regressions for startup failure, socket close/error/timeout, repeated disconnect, explicit destroy, active and queued callback/streaming queries, and a late ReadyForQuery event after destruction.

The test scripts invoke Mocha's runner directly because its old launcher exited without running tests on the current Node version.

This patch has not received live-database validation, been pushed, or been adopted by `protobi-sql`. It does not claim to fix every COPY source-stream failure or provide database-wide session budgeting. Live recovery validation and application integration remain separate gates.

## Follow-up: COPY source listener cleanup

COPY now detaches its source data/end/error listeners on CopyDone, CopyFail,
server rejection, ReadyForQuery, or connection failure. Captured listeners also
check COPY state, so an event emission already in progress cannot resume a
terminated transfer. Cleanup is idempotent and clears its query-held closure.

Caller-supplied streams are paused, not destroyed, and their existing listeners
are preserved. Callers retain ownership, including handling future stream errors
and disposing of streams they abandon. File streams opened by the driver are
destroyed; a temporary error listener covers pending file reads until close and
then removes itself without retaining the query.

Validation: all 102 unit tests pass. Live Vertica tests independently exercised
source failure before data, failure after sending data, and server rejection of
invalid input. Each failed COPY detached its listeners, allowed ROLLBACK, left
zero rows, and accepted a subsequent three-row COPY on the same connection.
Tests used session-local temporary tables; no existing table was changed.
An initial combined test failed an assertion between scenarios; the isolated
checks above establish per-scenario recovery, not repeated-cycle validation.
Live SELECT-only checks also passed graceful disconnect and forced destruction
with active/queued queries, confirmed socket closure, and replacement connections.

The driver changes remain local and are not yet adopted by protobi-sql.
