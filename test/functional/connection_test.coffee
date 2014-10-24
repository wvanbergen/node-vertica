path    = require 'path'
fs      = require 'fs'
assert  = require 'assert'
Vertica = require '../../src/vertica'
errors  = require '../../src/errors'

describe 'Vertica.connect', ->
  connectionInfo = null

  beforeEach ->
    if !fs.existsSync('./test/connection.json')
      throw new Error("Create test/connection.json to run functional tests")
    else
      connectionInfo = JSON.parse(fs.readFileSync('./test/connection.json'))

  it "should connect with proper credentials and yield a functional connection", (done) ->
    Vertica.connect connectionInfo, (err, connection) ->
      assert.equal err, null
      
      assert.ok !connection.busy
      assert.ok connection.connected
      
      connection.query "SELECT 1", (err, resultset) ->
        assert.equal err, null
        assert.ok resultset instanceof Vertica.Resultset
        assert.ok !connection.busy
        assert.ok connection.connected
        done()

      assert.ok connection.busy
      assert.ok connection.connected
      

  it "should fail to connect to an invalid host", (done) ->
    connectionInfo.host = 'fake'
    Vertica.connect connectionInfo, (err) ->
      assert.ok err?, "Connecting should fail with a fake host."
      done()


  it "should return an error if the connection attempt fails", (done) ->
    connectionInfo.password = 'absolute_nonsense'
    Vertica.connect connectionInfo, (err, _) ->
      assert err instanceof errors.AuthenticationError
      assert.equal err.code, '28000'
      done()


  it "should use SSL if requested", (done) ->
    connectionInfo.ssl = 'required'
    Vertica.connect connectionInfo, (err, connection) ->
      return done(err) if err?
      assert.ok connection.isSSL(), "Connection should be using SSL but isn't."
      done()

  it "should not use SSL if explicitely requested", (done) ->
    connectionInfo.ssl = false
    Vertica.connect connectionInfo, (err, connection) ->
      return done(err) if err?
      assert.ok !connection.isSSL()
      done()

  it "should be able to interrupt the session", (done) ->
    connectionInfo.interruptible = true
    Vertica.connect connectionInfo, (err, connection) ->
      return done(err) if err?

      setTimeout connection.interruptSession.bind(connection), 100
      connection.query "SELECT sleep(10)", (err, resultset) ->
        assert err instanceof errors.ConnectionError
        assert.equal err.message, 'The connection was closed.'
        done()

  describe 'Statement interruption', ->
    beforeEach (done) ->
      if !fs.existsSync('./test/connection.json')
        throw new Error("Create test/connection.json to run functional tests")
      else
        connectionInfo = JSON.parse(fs.readFileSync('./test/connection.json'))

      Vertica.connect connectionInfo, (err, connection) ->
        return done(err) if err?

        connection.query 'DROP TABLE IF EXISTS test_node_vertica_temp CASCADE', (err, rs) ->
          return done(err) if err?
      
          connection.query 'CREATE TABLE IF NOT EXISTS test_node_vertica_temp (value int);', (err, rs) ->
            return done(err) if err?

            dataHandler = (data, success) ->
              data([0...100].join('\n'))
              success()

            connection.copy 'COPY test_node_vertica_temp FROM STDIN ABORT ON ERROR', dataHandler, (err, rs) ->
              return done(err) if err?
              done()

    afterEach (done) ->
      Vertica.connect connectionInfo, (err, connection) ->
        return done(err) if err?

        connection.query 'DROP TABLE IF EXISTS test_node_vertica_temp CASCADE', (err, rs) ->
          return done(err) if err?
          done()

    it "should be able to interrupt a statement", (done) ->
      connectionInfo.interruptible = true
      Vertica.connect connectionInfo, (err, connection) ->
        
        # According to the Vertica documentation, SLEEP is not an
        # interruptiple operation. Therefore, we have to create an actual
        # long-running query. The simplest way to do this is to create a
        # multi full join of a table with itself.
        #
        # https://my.vertica.com/docs/7.0.x/HTML/Content/Authoring/SQLReferenceManual/Functions/VerticaFunctions/SLEEP.htm
        #
        setTimeout connection.interruptStatement.bind(connection), 100
        connection.query '''
          SELECT SUM(t0.value) FROM test_node_vertica_temp t0
            FULL OUTER JOIN test_node_vertica_temp t1 ON true
            FULL OUTER JOIN test_node_vertica_temp t2 ON true
            FULL OUTER JOIN test_node_vertica_temp t3 ON true
            FULL OUTER JOIN test_node_vertica_temp t4 ON true
            FULL OUTER JOIN test_node_vertica_temp t5 ON true
        ''', (err, resultset) ->
          assert err instanceof errors.QueryErrorResponse
          assert.equal err.message, 'Execution canceled by operator'
          done()
