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
    Vertica.connect connectionInfo, (err, connection) ->
      assert.ok err?, "Connecting should fail with a wrong password"
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
