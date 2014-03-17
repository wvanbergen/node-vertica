assert  = require 'assert'

Buffer          = require('../../src/buffer').Buffer
FrontendMessage = require('../../src/frontend_message')
Authentication  = require('../../src/authentication')

describe "FrontendMessage.Startup", ->
  it "should hold the message's information", ->
    topic = new FrontendMessage.Startup('username', 'database')
    assert.equal topic.user,     'username'
    assert.equal topic.database, 'database'
    assert.equal topic.options,  null

  it "should encode the message correctly", ->
    topic = new FrontendMessage.Startup('username', 'database')
    reference = new Buffer([0, 0, 0, 41, 0, 3, 0, 0, 117, 115, 101, 114, 0, 117, 115, 101, 114, 110, 97, 109, 101,
                            0, 100, 97, 116, 97, 98, 97, 115, 101, 0, 100, 97, 116, 97, 98, 97, 115, 101, 0, 0])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.CancelRequest", ->
  it "should hold the correct information",  ->
    topic = new FrontendMessage.CancelRequest(123, 456)
    assert.equal topic.backendPid, 123
    assert.equal topic.backendKey, 456

  it "should encode the message correctly", ->
    topic = new FrontendMessage.CancelRequest(123, 456)
    reference = new Buffer([0, 0, 0, 16, 4, 210, 22, 46, 0, 0, 0, 123, 0, 0, 1, 200])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Describe", ->
  describe "Portal", ->
    it "should hold the correct information", ->
      topic = new FrontendMessage.Describe('portal', 'name')
      assert.equal topic.type, 80
      assert.equal topic.name, 'name'

    it "should encode the message correctly", ->
      topic = new FrontendMessage.Describe('portal', 'name')
      reference = new Buffer([68, 0, 0, 0, 10, 80, 110, 97, 109, 101, 0])
      assert.deepEqual topic.toBuffer(), reference

  describe "Prepared statement", ->
    it "should hold the correct information", ->
      topic = new FrontendMessage.Describe('statement', 'name')
      assert.equal topic.type, 83
      assert.equal topic.name, 'name'

    it "should encode the message correctly", ->
      topic = new FrontendMessage.Describe('statement', 'name')
      reference = new Buffer([68, 0, 0, 0, 10, 83, 110, 97, 109, 101, 0])
      assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Close", ->
  describe "Portal", ->
    it "should hold the correct information", ->
      topic = new FrontendMessage.Close('portal', 'name')
      assert.equal topic.type, 80
      assert.equal topic.name, 'name'

    it "should encode the message correctly", ->
      topic = new FrontendMessage.Close('portal', 'name')
      reference = new Buffer([67, 0, 0, 0, 10, 80, 110, 97, 109, 101, 0])
      assert.deepEqual topic.toBuffer(), reference

  describe "Prepared statement", ->
    it "should hold the correct information", ->
      topic = new FrontendMessage.Close('statement', 'name')
      assert.equal topic.type, 83
      assert.equal topic.name, 'name'

    it "should encode the message correctly", ->
      topic = new FrontendMessage.Close('statement', 'name')
      reference = new Buffer([67, 0, 0, 0, 10, 83, 110, 97, 109, 101, 0])
      assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Query", ->
  it "should hold the SQL query", ->
    topic = new FrontendMessage.Query("SELECT * FROM table")
    assert.equal topic.sql, "SELECT * FROM table"

  it "should encode the message correctly", ->
    topic = new FrontendMessage.Query("SELECT * FROM table")
    reference = new Buffer([81, 0, 0, 0, 24, 83, 69, 76, 69, 67, 84, 32, 42, 32, 70, 82, 79, 77, 32, 116, 97, 98, 108, 101, 0])
    assert.deepEqual topic.toBuffer(), reference

  it "should encode non-latin UTF-8 strings", ->
    topic = new FrontendMessage.Query("SELECT 'Привет'")
    reference = new Buffer([81, 0, 0, 0, 26, 83, 69, 76, 69, 67, 84, 32, 39, 208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130, 39, 0])
    assert.deepEqual topic.toBuffer().toString(), reference.toString()


describe "FrontendMessage.Parse", ->
  it "should hold the name, query and parameter types", ->
    topic = new FrontendMessage.Parse("test", "SELECT * FROM table", [1, 2, 3])
    assert.equal topic.name, "test"
    assert.equal topic.sql,  "SELECT * FROM table"
    assert.deepEqual topic.parameterTypes, [1, 2, 3]

  it "should encode the message correctly", ->
    topic = new FrontendMessage.Parse("test", "SELECT * FROM table", [1, 2, 3])
    reference = new Buffer([80, 0, 0, 0, 43, 116, 101, 115, 116, 0, 83, 69, 76, 69, 67, 84, 32, 42, 32, 70, 82,
                            79, 77, 32, 116, 97, 98, 108, 101, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Bind", ->
  it "should hold the portal, prepared statement name and parameter values", ->
    topic = new FrontendMessage.Bind("portal", "prep", ["hello", "world", 123])
    assert.equal topic.portal, "portal"
    assert.equal topic.preparedStatement, "prep"
    assert.deepEqual topic.parameterValues, ["hello", "world", "123"]

  it "should encode the message correctly", ->
    topic = new FrontendMessage.Bind("portal", "prep", ["hello", "world", 123])
    assert.deepEqual topic.toBuffer(), new Buffer([66, 0, 0, 0, 45,
      112, 111, 114, 116, 97, 108, 0,  # "portal" (portal name)
      112, 114, 101, 112, 0,           # "prep" (prepared statement name)
      0, 0, 0, 3,                      # number of parameters (3)
      0, 0, 0, 5,                      # Length of first parameter (5)
      104, 101, 108, 108, 111,         # "hello"
      0, 0, 0, 5,                      # Length of second parameter (5)
      119, 111, 114, 108, 100,         # "world"
      0, 0, 0, 3,                      # Length of third parameter (3)
      49, 50, 51                       # "123"
    ])


describe "FrontendMessage.Flush", ->
  it "should encode the message correctly", ->
    topic = new FrontendMessage.Flush
    reference = new Buffer([72, 0, 0, 0, 4])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Execute", ->
  it "should hold portal name and maximum number of rows", ->
    topic = new FrontendMessage.Execute('portal', 100)
    assert.equal topic.portal, 'portal'
    assert.equal topic.maxRows, 100

  it "should encode the message correctly", ->
    topic = new FrontendMessage.Execute('portal', 100)
    reference = new Buffer([69, 0, 0, 0, 15, 112, 111, 114, 116, 97, 108, 0, 0, 0, 0, 100])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Sync", ->
  it "should encode the message correctly", ->
    topic = new FrontendMessage.Sync
    reference = new Buffer([83, 0, 0, 0, 4])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Terminate", ->
  it "should encode the message correctly", ->
    topic = new FrontendMessage.Terminate
    reference = new Buffer([88, 0, 0, 0, 4])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.SSLRequest", ->
  it "should encode the message correctly", ->
    topic = new FrontendMessage.SSLRequest
    reference = new Buffer([0, 0, 0, 8, 4, 210, 22, 47])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.Password", ->
  it "should encode cleartext password messages correctly", ->
    topic = new FrontendMessage.Password('password')
    reference = new Buffer([112, 0, 0, 0, 13, 112, 97, 115, 115, 119, 111, 114, 100, 0])
    assert.deepEqual topic.toBuffer(), reference

  it "should encode MD5-hashed password messages correctly", ->
    topic = new FrontendMessage.Password('password')
    topic.authMethod   = Authentication.methods.MD5_PASSWORD
    topic.options.salt = 123
    topic.options.user = 'user'

    reference = new Buffer([112, 0, 0, 0, 40, 109, 100, 53, 50, 53, 52, 52, 52, 51, 56, 54, 101, 100, 53, 56, 51, 98, 53, 57, 57, 53, 48, 100, 50, 56, 98, 56, 53, 55, 52, 56, 102, 56, 49, 51, 0])
    assert.deepEqual topic.toBuffer().toString(), reference.toString()


describe "FrontendMessage.CopyDone", ->
  it "should format the message correctly", ->
    topic = new FrontendMessage.CopyDone
    reference = new Buffer([99, 0, 0, 0, 4])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.CopyFail", ->
  it "should format the message correctly", ->
    topic = new FrontendMessage.CopyFail('error')
    reference = Buffer([102, 0, 0, 0, 10, 101, 114, 114, 111, 114, 0])
    assert.deepEqual topic.toBuffer(), reference


describe "FrontendMessage.CopyData", ->
  it "should format the message correctly", ->
    topic = new FrontendMessage.CopyData(new Buffer('123'))
    reference = new Buffer([100, 0, 0, 0, 7, 49, 50, 51])
    assert.deepEqual topic.toBuffer(), reference

  it "should work with both strings and buffers", ->
    topic = new FrontendMessage.CopyData(new Buffer('123'))
    other = new FrontendMessage.CopyData('123')
    assert.deepEqual topic.toBuffer(), other.toBuffer()
