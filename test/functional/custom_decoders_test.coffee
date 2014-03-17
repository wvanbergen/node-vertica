path    = require 'path'
fs      = require 'fs'
assert  = require 'assert'
Vertica = require '../../src/vertica'


describe 'Vertica.Connection#query with custom decoders', ->
  connection = null

  # connection override decoders for several types
  connectionDecoders =
    boolean : (buffer) -> "boolean #{buffer}"
    integer : (buffer) -> "integer #{buffer}"
    numeric : (buffer) -> "numeric #{buffer}"
    real    : (buffer) -> "real #{buffer}"
    string  : (buffer) -> "string #{buffer}"

  # query override decoders for these types
  queryDecoders =
    boolean : (buffer) -> "Qboolean #{buffer}"
    integer : (buffer) -> "Qinteger #{buffer}"


  before (done) ->
    if !fs.existsSync('./test/connection.json')
      done("Create test/connection.json to run functional tests")
    else
      connectionInfo = JSON.parse(fs.readFileSync('./test/connection.json'))
      connectionInfo.decoders = connectionDecoders
      connection = Vertica.connect(connectionInfo, done)


  it "should use the custom decoders for all queries on the connection", (done) ->
    sql = """
      SELECT CAST(9223372036854775807 as NUMERIC), 
             1, 
             1.1, 
             'String', 
             TRUE, 
             CAST(123 AS REAL), 
             CAST('2012-1-1' as Date)
    """

    connection.query sql, (err, resultset) ->
      return done(err) if err?

      assert.equal resultset.fields.length, 7
      assert.equal resultset.fields[0].type, "numeric"
      assert.equal resultset.fields[1].type, "integer"
      assert.equal resultset.fields[2].type, "numeric"
      assert.equal resultset.fields[3].type, "string"
      assert.equal resultset.fields[4].type, "boolean"
      assert.equal resultset.fields[5].type, "real"
      assert.equal resultset.fields[6].type, "date"

      assert.equal resultset.rows.length, 1
      assert.deepEqual resultset.rows[0], [
        connectionDecoders.numeric '9223372036854775807'
        connectionDecoders.integer '1'
        connectionDecoders.numeric '1.1'
        connectionDecoders.string 'String'
        connectionDecoders.boolean 't'
        connectionDecoders.real '123'
        new Vertica.Date(2012, 1, 1) # no custom decoder defined for this type
      ]

      done()

  it "should use the custom decoders for a single queries", (done) ->

    sql = """
      SELECT CAST(9223372036854775807 as NUMERIC), 
             1, 
             1.1, 
             'String', 
             TRUE, 
             CAST(123 AS REAL), 
             CAST('2012-1-1' as Date)
    """

    callback = (err, resultset) ->
      done(err) if err?

      assert.equal resultset.fields.length, 7
      assert.equal resultset.fields[0].type, "numeric"
      assert.equal resultset.fields[1].type, "integer"
      assert.equal resultset.fields[2].type, "numeric"
      assert.equal resultset.fields[3].type, "string"
      assert.equal resultset.fields[4].type, "boolean"
      assert.equal resultset.fields[5].type, "real"
      assert.equal resultset.fields[6].type, "date"

      assert.equal resultset.rows.length, 1
      assert.deepEqual resultset.rows[0], [
        connectionDecoders.numeric '9223372036854775807'
        queryDecoders.integer '1'
        connectionDecoders.numeric '1.1'
        connectionDecoders.string 'String'
        queryDecoders.boolean 't'
        connectionDecoders.real '123'
        new Vertica.Date(2012, 1, 1) # no custom decoder defined for this type
      ]

      done()

    query = connection.query sql, callback
    query.decoders = queryDecoders
