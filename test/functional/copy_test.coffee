path    = require 'path'
fs      = require 'fs'
assert  = require 'assert'
Vertica = require('../../src/vertica')
errors  = require('../../src/errors')

describe 'Vertica.Connection#copy', ->
  connection = null


  beforeEach (done) ->
    if !fs.existsSync('./test/connection.json')
      done("Create test/connection.json to run functional tests")
    else
      Vertica.connect JSON.parse(fs.readFileSync('./test/connection.json')), (err, conn) ->
        return done(err) if err?
        connection = conn

        runSetupQueries = (setupQueries, done) ->
          return done() if setupQueries.length == 0
          sql = setupQueries.shift()
          connection.query sql, (err, resultset) ->
            return done(err) if err?
            runSetupQueries(setupQueries, done)

        setupQueries = [
          "DROP TABLE IF EXISTS test_node_vertica_table CASCADE;"
          "CREATE TABLE test_node_vertica_table (id int, name varchar(100))"
          "CREATE PROJECTION IF NOT EXISTS test_node_vertica_table_p (id, name) AS SELECT * FROM test_node_vertica_table SEGMENTED BY HASH(id) ALL NODES OFFSET 1"
        ]
        runSetupQueries(setupQueries, done)


  afterEach ->
    connection.disconnect() if connection.connected
    connection = null


  it "should COPY data from a file", (done) ->
    copySQL  = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    copyFile = "./test/test_node_vertica_table.csv"
    connection.copy copySQL, copyFile, (err, _) ->
      return done(err) if err?
      
      verifySQL = "SELECT * FROM test_node_vertica_table ORDER BY id"
      connection.query verifySQL, (err, resultset) ->
        return done(err) if err?
        assert.deepEqual resultset.rows, [[11, "Stuff"], [12, "More stuff"], [13, "Final stuff"]]
        done()      


  it "should COPY data from a data handler function", (done) ->
    dataHandler = (data, success, fail) ->
      data("11|Stuff\r\n")
      data("12|More stuff\n13|Fin")
      data("al stuff\n")
      success()

    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.copy copySQL, dataHandler, (err, _) ->
      return done(err) if err?
      
      verifySQL = "SELECT * FROM test_node_vertica_table ORDER BY id"
      connection.query verifySQL, (err, resultset) ->
        return done(err) if err?
        assert.deepEqual resultset.rows, [[11, "Stuff"], [12, "More stuff"], [13, "Final stuff"]]
        done()


  it "should accept callbacks in a data handler function and call them in order", (done) ->
    callbackResults = []
    dataHandler = (data, success, fail) ->
      data("11|Stuff\n", -> callbackResults.push('data'))
      success(-> callbackResults.push('success'))

    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.copy copySQL, dataHandler, (err, _) ->
      return done(err) if err?

      # Data handler callbackes invoked by the time this callback returns
      assert.deepEqual callbackResults, ['data', 'success'], 'Callbacks called out of order or not at all'
      
      verifySQL = "SELECT * FROM test_node_vertica_table ORDER BY id"
      connection.query verifySQL, (err, resultset) ->
        return done(err) if err?
        assert.deepEqual resultset.rows, [[11, 'Stuff']]
        done()

    # Verify data handler callbacks were not invoked immediately in the copy method
    assert.deepEqual callbackResults, [], 'Callbacks called before they should be'


  if require('semver').gte(process.version, '0.10.0')
    it "should COPY data from a stream function", (done) ->
      stream = fs.createReadStream("./test/test_node_vertica_table.csv");
      copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
      connection.copy copySQL, stream, (err, _) ->
        stream.close()
        return done(err) if err?

        verifySQL = "SELECT * FROM test_node_vertica_table ORDER BY id"
        connection.query verifySQL, (err, resultset) ->
          return done(err) if err?
          assert.deepEqual resultset.rows, [[11, "Stuff"], [12, "More stuff"], [13, "Final stuff"]]
          done()


  it "should not load data if fail is called", (done) ->
    dataHandler = (data, success, fail) ->
      data("11|Stuff\r\n")
      data("12|More stuff\n13|Fin")
      data("al stuff\n")      
      fail("Sorry, not happening")

    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.copy copySQL, dataHandler, (err, _) ->
      return done("Copy error expected") unless err?
      assert.equal err.code, "08000"
      assert.equal err.message, "COPY: from stdin failed: Sorry, not happening"
      
      verifySQL = "SELECT * FROM test_node_vertica_table ORDER BY id"
      connection.query verifySQL, (err, resultset) ->
        return done(err) if err?
        assert.equal resultset.getLength(), 0
        done()


  it "should not load from a nonexisting file", (done) ->
    copyFile = './test/nonexisting.csv'
    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.copy copySQL, copyFile, (err, _) ->
      return done("Copy error expected") unless err?
      assert err instanceof errors.QueryError
      assert.equal err.code, "08000"
      assert.equal err.message, "COPY: from stdin failed: Could not find local file ./test/nonexisting.csv."
      done()


  it "should not load data if the input data is invalid", (done) ->
    dataHandler = (data, success, fail) ->
      data("Invalid data")
      success()

    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.copy copySQL, dataHandler, (err, _) ->
      return done("Copy error expected") unless err?
      assert err instanceof errors.QueryError
      assert.equal err.code, "22V04"
      
      verifySQL = "SELECT * FROM test_node_vertica_table ORDER BY id"
      connection.query verifySQL, (err, resultset) ->
        return done(err) if err?

        assert.equal resultset.getLength(), 0
        done()


  it "should fail when not providing a data source", (done) ->
    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.query copySQL, (err, _) ->
      return done("Copy error expected") unless err?
      assert err instanceof errors.QueryError
      assert.equal err.code, '08000'
      assert.equal err.message, 'COPY: from stdin failed: No copy in handler defined to handle the COPY statement.'
      done()


  it "should fail when throwing an error in the copy handler", (done) ->
    dataHandler = (data, success, fail) ->
      throw new Error("Shit hits the fan!")

    copySQL = "COPY test_node_vertica_table FROM STDIN ABORT ON ERROR"
    connection.copy copySQL, dataHandler, (err, _) ->
      return done("Copy error expected") unless err?
      assert err instanceof errors.QueryError
      assert.equal err.code, "08000"
      assert.equal err.message, "COPY: from stdin failed: Shit hits the fan!"
      done()


  it "should fail gracefully when using COPY FROM LOCAL", (done) ->
    copyFile = "./test/test_node_vertica_table.csv"
    copySQL  = "COPY test_node_vertica_table FROM LOCAL #{Vertica.quote(copyFile)} ABORT ON ERROR"

    connection.once 'error', (err) ->
      assert.equal err.message, 'COPY FROM LOCAL is not supported.'
      done()

    connection.query copySQL, (err, rs) ->
      done("Copy error expected") unless err?
