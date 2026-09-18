const assert = require('assert')
const EventEmitter = require('events').EventEmitter
const Query = require('../../lib/query')

function fixture() {
    const connection = new EventEmitter()
    const writes = []
    connection._writeMessage = message => writes.push(message.toBuffer()[0])
    const source = new EventEmitter()
    source.read = function () {}
    source.push = function () {}
    source.pause = function () { source.paused = true }
    const ownerError = function () {}
    source.on('error', ownerError)
    const query = new Query(connection, 'COPY example FROM STDIN', function () {})
    query.copyInSource = source
    query.onCopyInResponse({})
    return {query, source, writes, ownerError}
}

function assertClean(f) {
    assert.strictEqual(f.source.listenerCount('data'), 0)
    assert.strictEqual(f.source.listenerCount('end'), 0)
    assert.deepStrictEqual(f.source.listeners('error'), [f.ownerError])
    assert.strictEqual(f.source.paused, true)
    assert.strictEqual(f.query._handlingCopyIn, false)
    assert.strictEqual(f.query._copySourceCleanup, null)
    const count = f.writes.length
    f.source.emit('data', Buffer.from('late'))
    f.source.emit('end')
    f.source.emit('error', new Error('late source error'))
    assert.strictEqual(f.writes.length, count)
}

describe('COPY source lifecycle', function () {
    it('detaches only driver listeners when the source ends', function () {
        const f = fixture()
        f.source.emit('data', Buffer.from('1\n'))
        f.source.emit('end')
        assert.deepStrictEqual(f.writes, [100, 99]) // CopyData, CopyDone
        assertClean(f)
    })
    it('sends CopyFail once and detaches when the source fails', function () {
        const f = fixture()
        f.source.emit('error', new Error('source failed'))
        assert.deepStrictEqual(f.writes, [102])
        assertClean(f)
    })
    it('stops the source immediately on a server error', function () {
        const f = fixture()
        f.query.onErrorResponse({information: {Message: 'rejected', Code: '22V04'}})
        assertClean(f)
        assert.deepStrictEqual(f.writes, [])
    })
    it('stops the source on connection failure without writing CopyFail', function () {
        const f = fixture()
        f.query.onConnectionError(new Error('closed'))
        assertClean(f)
        assert.deepStrictEqual(f.writes, [])
    })
    it('cleans up idempotently on ReadyForQuery', function () {
        const f = fixture()
        f.query.onReadyForQuery({})
        f.query.onReadyForQuery({})
        assertClean(f)
    })
    it('guards listeners already captured by an in-progress event emission', function () {
        const f = fixture()
        const data = f.source.listeners('data')[0]
        const end = f.source.listeners('end')[0]
        const error = f.source.listeners('error')[1]
        f.query.onConnectionError(new Error('closed'))
        data(Buffer.from('late')); end(); error(new Error('late'))
        assert.deepStrictEqual(f.writes, [])
        assertClean(f)
    })
})

describe('driver-owned COPY file stream', function () {
    it('destroys its source and absorbs pending read errors only until close', function () {
        const f = fixture()
        f.query._stopCopyIn()
        f.source.removeListener('error', f.ownerError)
        f.source.destroy = function () { f.source.destroyed = true }
        f.query._handlingCopyIn = true
        f.query._getStreamCopyInHandler(f.source, true)(function () {}, function () {}, function () {})
        f.query.onConnectionError(new Error('closed'))
        assert.strictEqual(f.source.destroyed, true)
        assert.doesNotThrow(() => f.source.emit('error', new Error('pending read')))
        f.source.emit('close')
        assert.strictEqual(f.source.listenerCount('error'), 0)
        assert.strictEqual(f.source.listenerCount('close'), 0)
    })
})
