vows   = require 'vows'
assert = require 'assert'

Buffer = require('../lib/vertica/buffer').Buffer

vow = vows.describe('Buffer')

vow.addBatch
  "writing unsigned integers":
    topic: -> new Buffer(4)
  
    "it should encode 8-bit integers at the correct position": (topic) -> 
      topic.writeUInt8(255) # default offset == 0
      topic.writeUInt8(127, 3)
      assert.equal topic[0], 255
      assert.equal topic[3], 127
    
    "it should store 32-bit integers with big endian encoding": (topic) ->
      topic.writeUInt32(16909060)
      assert.equal topic[0], 1
      assert.equal topic[1], 2
      assert.equal topic[2], 3
      assert.equal topic[3], 4

    "it should store 32-bit integers with little endian encoding": (topic) ->
      topic.writeUInt32(16909060, 0, 'little')
      assert.equal topic[0], 4
      assert.equal topic[1], 3
      assert.equal topic[2], 2
      assert.equal topic[3], 1


  "reading unsigned integers":
    topic: -> new Buffer([1,2,3,4])
    
    "it should read 8-bit integers from the correct location": (topic) ->
      assert.equal topic.readUInt8(), 1  # default offset == 0
      assert.equal topic.readUInt8(1), 2
      assert.equal topic.readUInt8(2), 3
      assert.equal topic.readUInt8(3), 4

    "it should read 32-bit big endian integers correctly": (topic) ->
      assert.equal topic.readUInt32(0, 'big'), 16909060

    "it should read 32-bit little endian integers correctly": (topic) ->
      assert.equal topic.readUInt32(0, 'little'), 67305985

vow.export(module)
