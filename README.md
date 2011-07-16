# node-vertica

A pure javascript library to connect to a Vertica database.

## Example

```coffeescript

Vertica = require 'vertica'

connection = Vertica.connect user: "username", password: 'password', database: "database", host: 'localhost', (conn) ->
  
  query = conn.query "SELECT * FROM table"
  query.on 'fields', (fields) ->
    console.log("Fields:", fields)

  query.on 'row', (row) ->
    console.log(row)

  query.on 'end', (status) ->
    console.log("Finished!", status)

```
