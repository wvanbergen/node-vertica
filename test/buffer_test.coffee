vows   = require 'vows'
assert = require 'assert'

Buffer = require('../src/buffer').Buffer

vow = vows.describe('Buffer')

vow.addBatch
  
  "writing zero-terminated strings":
    topic: -> new Buffer([1,1,1,1,1])
    
    "it should write a zero terminated string correctly": (topic) ->
      topic.writeZeroTerminatedString('test', 0)
      assert.deepEqual topic, new Buffer([116, 101, 115, 116, 0])

  
  "reading zero-terminated strings":
    topic: -> new Buffer([80,0,80,80,0])

    "it should read a string at the beginning of the buffer": (topic) ->
      assert.equal topic.readZeroTerminatedString(0), 'P'

    "it should read a string in the middle of the buffer": (topic) ->
      assert.equal topic.readZeroTerminatedString(2), 'PP'


vow.export(module)
