vows    = require 'vows'
assert  = require 'assert'

Buffer          = require('../src/buffer').Buffer
FrontendMessage = require('../src/frontend_message')
Authentication  = require('../src/authentication')

vow = vows.describe('FrontendMessage')

vow.addBatch
  "Startup message":
    topic: -> new FrontendMessage.Startup('username', 'database')

    "it should hold the message's information": (topic) ->
      assert.equal topic.user,     'username'
      assert.equal topic.database, 'database'
      assert.equal topic.options,  null

    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([0, 0, 0, 41, 0, 3, 0, 0, 117, 115, 101, 114, 0, 117, 115, 101, 114, 110, 97, 109, 101, 
                              0, 100, 97, 116, 97, 98, 97, 115, 101, 0, 100, 97, 116, 97, 98, 97, 115, 101, 0, 0])
      assert.deepEqual topic.toBuffer(), reference
      

  "CancelRequest message":
    topic: -> new FrontendMessage.CancelRequest(123, 456)

    "it should hold the correct information": (topic) ->
      assert.equal topic.backendPid, 123
      assert.equal topic.backendKey, 456
  
    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([0, 0, 0, 16, 4, 210, 22, 46, 0, 0, 0, 123, 0, 0, 1, 200])
      assert.deepEqual topic.toBuffer(), reference
      
      
  "Describe message":
    'Portal description':
      topic: -> new FrontendMessage.Describe('portal', 'name')
    
      "it should hold the correct information": (topic) ->
        assert.equal topic.type, 80
        assert.equal topic.name, 'name'
    
      "it should encode the message correctly": (topic) -> 
        reference = new Buffer([68, 0, 0, 0, 10, 80, 110, 97, 109, 101, 0])
        assert.deepEqual topic.toBuffer(), reference
    
    'Prepared statement description':
      topic: -> new FrontendMessage.Describe('statement', 'name')

      "it should hold the correct information": (topic) ->
        assert.equal topic.type, 83
        assert.equal topic.name, 'name'
      
      "it should encode the message correctly": (topic) -> 
        reference = new Buffer([68, 0, 0, 0, 10, 83, 110, 97, 109, 101, 0])
        assert.deepEqual topic.toBuffer(), reference

  "Close message":
    'closing a portal':
      topic: -> new FrontendMessage.Close('portal', 'name')

      "it should hold the correct information": (topic) ->
        assert.equal topic.type, 80
        assert.equal topic.name, 'name'

      "it should encode the message correctly": (topic) -> 
        reference = new Buffer([67, 0, 0, 0, 10, 80, 110, 97, 109, 101, 0])
        assert.deepEqual topic.toBuffer(), reference

    'closing a prepared statement':
      topic: -> new FrontendMessage.Close('statement', 'name')

      "it should hold the correct information": (topic) ->
        assert.equal topic.type, 83
        assert.equal topic.name, 'name'

      "it should encode the message correctly": (topic) -> 
        reference = new Buffer([67, 0, 0, 0, 10, 83, 110, 97, 109, 101, 0])
        assert.deepEqual topic.toBuffer(), reference


  "Query message":
    topic: -> new FrontendMessage.Query("SELECT * FROM table")
  
    "it should hold the SQL query": (topic) ->
      assert.equal topic.sql, "SELECT * FROM table"

    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([81, 0, 0, 0, 24, 83, 69, 76, 69, 67, 84, 32, 42, 32, 70, 82, 79, 77, 32, 116, 97, 98, 108, 101, 0])
      assert.deepEqual topic.toBuffer(), reference

  "Parse message":
    topic: -> new FrontendMessage.Parse("test", "SELECT * FROM table", [1, 2, 3])
      
    "it should hold the name, query and parameter types": (topic) ->
      assert.equal topic.name, "test"
      assert.equal topic.sql,  "SELECT * FROM table"
      assert.deepEqual topic.parameterTypes, [1, 2, 3]
    
    "it should encode the message correctly": (topic) ->
      reference = new Buffer([80, 0, 0, 0, 43, 116, 101, 115, 116, 0, 83, 69, 76, 69, 67, 84, 32, 42, 32, 70, 82, 
                              79, 77, 32, 116, 97, 98, 108, 101, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3])
      assert.deepEqual topic.toBuffer(), reference
  
  "Bind message":
    topic: -> new FrontendMessage.Bind("portal", "prep", ["hello", "world", 123])
    
    "it should hold the portal, prepared statement name and parameter values": (topic) ->
      assert.equal topic.portal, "portal"
      assert.equal topic.preparedStatement, "prep"
      assert.deepEqual topic.parameterValues, ["hello", "world", "123"]
  
    "it should encode the message correctly": (topic) ->
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

  "Flush message":
    topic: -> new FrontendMessage.Flush

    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([72, 0, 0, 0, 4])
      assert.deepEqual topic.toBuffer(), reference


  "Execute message":
    topic: -> new FrontendMessage.Execute('portal', 100)
    
    "it should hold portal name and maximum number of rows": (topic) ->
      assert.equal topic.portal, 'portal'
      assert.equal topic.maxRows, 100
    
    "it should encode the message correctly": (topic) ->
      reference = new Buffer([69, 0, 0, 0, 15, 112, 111, 114, 116, 97, 108, 0, 0, 0, 0, 100])
      assert.deepEqual topic.toBuffer(), reference


  "Sync message":
    topic: -> new FrontendMessage.Sync

    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([83, 0, 0, 0, 4])
      assert.deepEqual topic.toBuffer(), reference


  "Terminate message":
    topic: -> new FrontendMessage.Terminate

    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([88, 0, 0, 0, 4])
      assert.deepEqual topic.toBuffer(), reference


  "SSLRequest message":
    topic: -> new FrontendMessage.SSLRequest

    "it should encode the message correctly": (topic) -> 
      reference = new Buffer([0, 0, 0, 8, 4, 210, 22, 47])
      assert.deepEqual topic.toBuffer(), reference


  "Password message":
    topic: -> new FrontendMessage.Password('password')
    
    "it should encode cleartext password messages correctly": (topic) ->
      reference = new Buffer([112, 0, 0, 0, 13, 112, 97, 115, 115, 119, 111, 114, 100, 0])
      assert.deepEqual topic.toBuffer(), reference

    "it should encode MD5-hashed password messages correctly": (topic) ->
      topic.authMethod   = Authentication.methods.MD5_PASSWORD
      topic.options.salt = 'salt'
      topic.options.user = 'user'
      reference = new Buffer([112, 0, 0, 0, 40, 109, 100, 53, 56, 101, 57, 57, 56, 97, 97, 97, 54, 54, 98, 100, 51, 48, 50, 101, 53, 53, 57, 50, 100, 102, 51, 54, 52, 50, 99, 49, 54, 102, 55, 56, 0])
      assert.deepEqual topic.toBuffer().toString(), reference.toString()


  "CopyDone message":
    topic: -> new FrontendMessage.CopyDone()

    "it should format the message correctly": (topic) ->
      reference = new Buffer([99, 0, 0, 0, 4])
      assert.deepEqual topic.toBuffer(), reference

  "CopyFail message":
    topic: -> new FrontendMessage.CopyFail('error')

    "it should format the message correctly": (topic) ->
      reference = Buffer([102, 0, 0, 0, 10, 101, 114, 114, 111, 114, 0])
      assert.deepEqual topic.toBuffer(), reference

  "CopyData message":
    topic: -> new FrontendMessage.CopyData(new Buffer('123'))

    "it should format the message correctly": (topic) ->
      reference = new Buffer([100, 0, 0, 0, 7, 49, 50, 51])
      assert.deepEqual topic.toBuffer(), reference

    "it should work with both strings and buffers": (topic) ->
      other = new FrontendMessage.CopyData('123')
      assert.deepEqual topic.toBuffer(), other.toBuffer()


vow.export(module)

