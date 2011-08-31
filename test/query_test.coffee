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
        assert.length fields, 6
        assert.equal fields[0].name, "field"
        assert.equal fields[1].type, "integer"
        assert.equal fields[2].type, "numeric"
        assert.equal fields[3].type, "string"
        assert.equal fields[4].type, "boolean"
        assert.equal fields[5].type, "boolean"

      "it should return rows": (err, fields, rows, status) ->
        assert.length rows, 1
        assert.deepEqual rows[0], [null, 1, 1.1, 'String', true, false]

      "it should return SELECT as status": (err, fields, rows, status) ->
        assert.equal status, "SELECT"

    "Dealing with dates, intervals and timestamps"


  vow.export(module)
