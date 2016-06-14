path    = require 'path'
fs      = require 'fs'
assert  = require 'assert'
Vertica = require('../../src/vertica')
errors  = require('../../src/errors')

describe 'Vertica.Connection#query', ->
  connection = null

  before (done) ->
    if !fs.existsSync('./test/connection.json')
      done("Create test/connection.json to run functional tests")
    else
      connection = Vertica.connect JSON.parse(fs.readFileSync('./test/connection.json')), done


  after ->
    connection.disconnect() if connection.connected


  describe "Simple SELECT query", ->
    resultset = null

    beforeEach (done) ->
      connection.query "SELECT NULL AS field, 1, 1.1, 'String', TRUE, FALSE", (err, result) ->
        return done(err) if err
        resultset = result
        done()

    it "should return fields", ->
      assert.equal resultset.fields.length, 6
      assert.equal resultset.fields[0].name, "field"
      assert.equal resultset.fields[1].type, "integer"
      assert.equal resultset.fields[2].type, "numeric"
      assert.equal resultset.fields[3].type, "string"
      assert.equal resultset.fields[4].type, "boolean"
      assert.equal resultset.fields[5].type, "boolean"

    it "it should return rows", ->
      assert.equal resultset.rows.length, 1
      assert.deepEqual resultset.rows[0], [null, 1, 1.1, 'String', true, false]

    it "it should return SELECT as status", ->
      assert.equal resultset.status, "SELECT"

    it "results should be JSON.stringify-able", ->
      assert.doesNotThrow -> JSON.stringify(resultset)


  describe "date and timestamp handling", ->
    resultset = null

    beforeEach (done) ->
      sql = "SELECT '2010-01-01'::date, '2010-01-01 12:30:00'::timestamp, '30 DAY'::interval, '04:05:06'::time"
      connection.query sql, (err, result) ->
        return done(err) if err
        resultset = result
        done()

    it "should return a resultset instance", ->
      assert.ok resultset instanceof Vertica.Resultset

    it "should return fields", ->
      assert.equal resultset.fields.length, 4
      assert.equal resultset.fields[0].type, "date"
      assert.equal resultset.fields[1].type, "timestamp"
      assert.equal resultset.fields[2].type, "interval"
      assert.equal resultset.fields[3].type, "time"

    it "should return rows", ->
      assert.equal resultset.rows.length, 1
      assert.deepEqual resultset.rows[0], [
        new Vertica.Date(2010,1,1), 
        new Date(Date.UTC(2010, 0, 1, 12, 30, 0)), 
        new Vertica.Interval(30), 
        new Vertica.Time(4,5,6)
      ]

    it "should be able to JSON.stringify the result", ->
      assert.doesNotThrow -> JSON.stringify(resultset)


  describe "Running an empty query", ->
    it "should return an error", (done) ->
      connection.query " ", (err, _) ->
        assert err instanceof errors.QueryError
        assert.equal err.message, "The query was empty!"
        done()

    it "should return the result of the second query", (done) ->
      connection.query " ", (err, _) ->
        connection.query "SELECT 1", (err, resultset) ->
          assert.equal err, null
          assert.equal resultset.theValue(), 1
          done()


  describe "Running an invalid query", ->
    it "should return an error", (done) ->
      connection.query "FAIL", (err, _) ->
      assert.ok typeof err, 'string'
      done()

    it "should return multi-queries error", (done) ->
      sql = "SELECT 1; SELECT 1"
      connection.query sql, (err, _) ->
        assert.ok typeof err, 'string'
        assert.equal err.message, "Cannot handle multi-queries with a callback!"
        connection.query "SELECT 1", (err, _) -> done err

    it "should be able to reuse the connection afterwards", (done) ->
      connection.query "FAIL", (err, _) ->
        connection.query "SELECT 1", (err, resultset) ->
          assert.equal err, null
          assert.equal resultset.theValue(), 1
          done()


  describe "Calling system status functions and querying tables", ->
    it "should handle the result of a system function", (done) ->
      connection.query "SELECT DISPLAY_LICENSE()", (err, resultset) ->
        assert.equal err, null
        assert.ok resultset instanceof Vertica.Resultset
        assert.ok typeof resultset.theValue()  == 'string'
        done()

    it "should handle querying the system tables", (done) ->
      connection.query "SELECT * FROM SYSTEM_TABLES", (err, resultset) ->
        assert.equal err, null
        assert.ok resultset instanceof Vertica.Resultset
        assert.ok resultset.rows.length > 0
        done()
