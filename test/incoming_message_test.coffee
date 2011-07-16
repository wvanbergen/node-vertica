vows    = require 'vows'
assert  = require 'assert'


IncomingMessage = require('../src/incoming_message')
Buffer = require('../src/buffer').Buffer

vow = vows.describe('IncomingMessage')

vow.addBatch 
  'Authentication message':
    "it should read a message correctly": (topic) ->
      message = IncomingMessage.fromBuffer(new Buffer([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00]))

      assert.equal message.__proto__.constructor, IncomingMessage.Authentication 
      assert.equal message.method, 0


  'ParameterStatus message':
    "it should read a message correctly": (topic) ->
      message = IncomingMessage.fromBuffer(new Buffer([0x53, 0x00, 0x00, 0x00, 0x16, 0x61, 0x70, 0x70, 0x6c, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x5f, 0x6e, 0x61, 0x6d, 0x65, 0x00, 0x00]))

      assert.equal message.__proto__.constructor, IncomingMessage.ParameterStatus 
      assert.equal message.name,  'application_name'
      assert.equal message.value, ''


  'BackendKeyData message':  
    "it should read a message correctly": (topic) ->
      message = IncomingMessage.fromBuffer(new Buffer([0x4b, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x95, 0xb4, 0x66, 0x62, 0xa0, 0xd5]))

      assert.equal message.__proto__.constructor, IncomingMessage.BackendKeyData 
      assert.equal message.pid, 38324
      assert.equal message.key, 1717739733


  'ReadyForQuery message':
    "it should read a message correctly": (topic) ->
      message = IncomingMessage.fromBuffer(new Buffer([0x5a, 0x00, 0x00, 0x00, 0x05, 0x49]))

      assert.equal message.__proto__.constructor, IncomingMessage.ReadyForQuery
      assert.equal message.transactionStatus, 0x49


vow.export(module)
