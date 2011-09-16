# node-vertica

A pure javascript library to connect to a Vertica database.

## Installation

    npm install vertica

## Example

```coffeescript

Vertica = require 'vertica'

connection = Vertica.connect user: "username", password: 'password', database: "database", host: 'localhost', (err) ->
  throw err if err
  
  # unbuffered
  query = connection.query "SELECT * FROM table"
  query.on 'fields', (fields) ->
    console.log("Fields:", fields)

  query.on 'row', (row) ->
    console.log(row)

  query.on 'end', (status) ->
    console.log("Finished!", status)

  # buffered
  connection.query "SELECT * FROM table", (err, resultset) ->
    console.log err, resultset.fields, resultset.rows, resultset.status

```
