path   = require 'path'
fs     = require 'fs'
vows   = require 'vows'
assert = require 'assert'

if !path.existsSync('./test/connection.json')
  console.error "Create test/connection.json to run functional tests"

else
  Vertica = require('../src/vertica')
  connection = Vertica.connect JSON.parse(fs.readFileSync('./test/connection.json')), (err) ->
    if err
      console.error "\n\n#{err}"
      console.error "Please make sure that you credentials in test/connection.json are correct."
      throw "Database connection required for functional tests."


  # help function to run queries as a topic
  query = (sql, callback) ->
    connection.query(sql, callback)
    undefined
  

  vow = vows.describe('Query')

  vow.addBatch
    "Running a simple SELECT query":
      topic: -> query("SELECT NULL AS field, 1, 1.1, 'String', TRUE, FALSE", @callback)
    
      "it should not have an error message": (err, _) ->
        assert.equal err, null
      
      "it should return fields": (err, fields, rows, status) ->
        assert.equal fields.length, 6
        assert.equal fields[0].name, "field"
        assert.equal fields[1].type, "integer"
        assert.equal fields[2].type, "numeric"
        assert.equal fields[3].type, "string"
        assert.equal fields[4].type, "boolean"
        assert.equal fields[5].type, "boolean"

      "it should return rows": (err, fields, rows, status) ->
        assert.equal rows.length, 1
        assert.deepEqual rows[0], [null, 1, 1.1, 'String', true, false]

      "it should return SELECT as status": (err, fields, rows, status) ->
        assert.equal status, "SELECT"

      "results should be JSON.stringifyp-able": (err, fields, rows, status) ->
        assert.doesNotThrow -> JSON.stringify(err)
        assert.doesNotThrow -> JSON.stringify(fields)
        assert.doesNotThrow -> JSON.stringify(rows)
        assert.doesNotThrow -> JSON.stringify(status)

    "Dealing with dates and times":
      topic: -> query("SELECT '2010-01-01'::date, '2010-01-01 12:30:00'::timestamp, '30 DAY'::interval, '04:05:06'::time", @callback)
      
      "it should not have an error message": (err, _) ->
        assert.equal err, null
        
      "it should return fields": (err, fields, rows, status) ->
        assert.equal fields.length, 4
        assert.equal fields[0].type, "date"
        assert.equal fields[1].type, "timestamp"
        assert.equal fields[2].type, "interval"
        assert.equal fields[3].type, "time"
        
      "it should return rows": (err, fields, rows, status) ->
        assert.equal rows.length, 1
        assert.deepEqual rows[0], [new Vertica.Date(2010,1,1), new Date(Date.UTC(2010, 0, 1, 12, 30, 0)), new Vertica.Interval(30), new Vertica.Time(4,5,6)]
      
      "results should be JSON.stringifyp-able": (err, fields, rows, status) ->
        assert.doesNotThrow -> JSON.stringify(err)
        assert.doesNotThrow -> JSON.stringify(fields)
        assert.doesNotThrow -> JSON.stringify(rows)
        assert.doesNotThrow -> JSON.stringify(status)
    

  vow.export(module)
