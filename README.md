# node-vertica [![Build Status](https://travis-ci.org/wvanbergen/node-vertica.png?branch=travis)](https://travis-ci.org/wvanbergen/node-vertica)

> WARNING: this library is not maintained. 

A pure javascript library to connect to a Vertica database. Except that it is written in CoffeeScript.

## Installation

    npm install vertica

## Getting started

### Connecting

Call the `connect` method with a connection options object. The following connection
options are supported.

- `host`: the host to connect to (default: `"localhost"`)
- `port`: the remote port to connect to (default: `5433`)
- `user`: the username to use for authentication
- `password`: the password to use for authentication
- `database`: the database to connect to. If your Vertica server only has a single
  database, you can leave this blank.
- `ssl`: whether to encrypt the connection using SSL. The following values are supported:
    - `false`: no SSL
    - `"optional"`: use SSL if the server supports it, but fall back to no SSL if not (default).
    - `"required"`: use SSL, throw an error if the server doesn't support it.
    - `"verified"`: use SSL, throw an error if the server doesn't support it or its SSL
      certificate could not be verified.
- `role`: Runs a `SET ROLE` query to activate a role for the user immediately after connecting.
- `searchPath`: Runs a `SET SEARCH_PATH TO` query to set the search path after connecting.
- `timezone`: Runs a `SET TIMEZONE TO` query to set the connection's time zone after connecting.
- `initializer`: a callback function that gets called after connection but before any query
  gets executed.
- `decoders`: an object containing custom buffer decoders for query result field deserialization, see usage in custom decoders test.

```coffeescript

Vertica = require 'vertica'
connection = Vertica.connect host: 'localhost', user: "me", password: 'secret', (err) ->
  throw err if err
```

*Note:* the `connect` will establish a single connection. A connection can only execute
one query at the time. Due to the evented nature of node.js, it is possible to start a new
query while another query is still running. This library implements a simple queueing
system that will run queries serially.

If you want parallelism, you will need multiple connections to your server. You can set up
connection pooling fairly easily using the `generic-pool` library. Note that transactions
cannot be shared between multiple connections; you need to use the same connection for all
queries in the transaction and run them in serial.

#### Example Create Function for `generic-pool`
```coffeescript
pool = genericPool.Pool(
  create: (callback) ->
    vertica.connect {}, (err, conn) ->
      callback err, conn
)
```

### Querying (buffered)

Running a buffered query will assemble the result in memory and call the callback
function when it is completed.

```coffeescript

connection = Vertica.connect(...)
connection.query "SELECT * FROM table", (err, resultset) ->
  console.log err, resultset.fields, resultset.rows, resultset.status

# or, identically:

query = Vertica.connect(...).query "SELECT * FROM table"
query.callback = (err, resultset) -> ...
```

### Querying (unbuffered)

Running an unbuffered query will immediately emit incoming data as events and
will not store the result in memory. Recommended for handling huge resultsets.

```coffeescript

connection = Vertica.connect(...)
query = connection.query "SELECT * FROM table"

# 'fields' is emitted once.
query.on 'fields', (fields) -> console.log("Fields:", fields)

# 'row' is emitted 0..* times, once for every row in the resultset.
query.on 'row', (row) -> console.log(row)

# 'end' is emitted once.
query.on 'end', (status) -> console.log("Finished!", status)

# If 'error' is emitted, no more events will follow.
# If no event handler is implemented, an exceptions gets thrown instead.
query.on 'error', (err) -> console.log("Uh oh!", err)
```

## About

- MIT licensed (see LICENSE).
- Written by Willem van Bergen for Shopify Inc.
- Pull requests are gladly accepted. Please modify the CoffeeScript source files
  in the `/src` folder, and not the compiled JavaScript output files.
