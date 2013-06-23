path   = require 'path'
fs     = require 'fs'
vows   = require 'vows'
assert = require 'assert'

if !fs.existsSync('./test/connection.json')
  console.error "Create test/connection.json to run functional tests"

else

  # connection override decoders for these types
  decoders =
    boolean : (buffer) -> "boolean #{buffer}"
    integer : (buffer) -> "integer #{buffer}"
    numeric : (buffer) -> "numeric #{buffer}"
    real    : (buffer) -> "real #{buffer}"
    string  : (buffer) -> "string #{buffer}"

  # query override decoders for these types
  queryDecoders =
    boolean : (buffer) -> "Qboolean #{buffer}"
    integer : (buffer) -> "Qinteger #{buffer}"

  Vertica = require('../src/vertica')
  preferences = JSON.parse fs.readFileSync('./test/connection.json')

  # load custom decoders
  preferences.decoders = decoders

  connection = Vertica.connect preferences, (err) ->
    if err
      console.error "\n\n#{err}"
      console.error "Please make sure that you credentials in test/connection.json are correct."
      throw "Database connection required for functional tests."


  # help function to run queries as a topic
  query = (sql, callback) ->
    return connection.query(sql, callback)

  vow = vows.describe('Query')

  vow.addBatch
    "Using connection with custom decoders":
      topic: ->
        sql = "SELECT CAST(9223372036854775807 as NUMERIC), 1, 1.1, 'String', TRUE, CAST(123 AS REAL), CAST('2012-1-1' as Date)"
        query(sql, @callback)
        undefined

      "it should return fields": (err, resultset) ->
        assert.equal resultset.fields.length, 7
        assert.equal resultset.fields[0].type, "numeric"
        assert.equal resultset.fields[1].type, "integer"
        assert.equal resultset.fields[2].type, "numeric"
        assert.equal resultset.fields[3].type, "string"
        assert.equal resultset.fields[4].type, "boolean"
        assert.equal resultset.fields[5].type, "real"
        assert.equal resultset.fields[6].type, "date"

      "it should return rows": (err, resultset) ->
        assert.equal resultset.rows.length, 1

        col1 = decoders.numeric '9223372036854775807'
        col2 = decoders.integer '1'
        col3 = decoders.numeric '1.1'
        col4 = decoders.string 'String'
        col5 = decoders.boolean 't'
        col6 = decoders.real '123'

        # no custom decoder defined for this type
        col7 = new Vertica.Date(2012, 1, 1)

        assert.deepEqual resultset.rows[0], [col1, col2, col3, col4, col5, col6, col7]

  vow.addBatch
    "Using query with custom decoders":
      topic: ->
        sql = "SELECT CAST(9223372036854775807 as NUMERIC), 1, 1.1, 'String', TRUE, CAST(123 AS REAL), CAST('2012-1-1' as Date)"
        query = query(sql, @callback)
        # set up custom decoder just for this query
        query.decoders = queryDecoders
        undefined

      "it should return fields": (err, resultset) ->
        assert.equal resultset.fields.length, 7
        assert.equal resultset.fields[0].type, "numeric"
        assert.equal resultset.fields[1].type, "integer"
        assert.equal resultset.fields[2].type, "numeric"
        assert.equal resultset.fields[3].type, "string"
        assert.equal resultset.fields[4].type, "boolean"
        assert.equal resultset.fields[5].type, "real"
        assert.equal resultset.fields[6].type, "date"

      "it should return rows": (err, resultset) ->
        assert.equal resultset.rows.length, 1

        col1 = decoders.numeric '9223372036854775807'
        col2 = queryDecoders.integer '1'
        col3 = decoders.numeric '1.1'
        col4 = decoders.string 'String'
        col5 = queryDecoders.boolean 't'
        col6 = decoders.real '123'

        # no custom decoder defined for this type
        col7 = new Vertica.Date(2012, 1, 1)

        assert.deepEqual resultset.rows[0], [col1, col2, col3, col4, col5, col6, col7]

  vow.export(module)
