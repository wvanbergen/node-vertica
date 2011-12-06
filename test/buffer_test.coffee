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


  "writing unsigned integers":
    topic: -> new Buffer(4)
  
    "it should write 8-bit integers at the correct position": (topic) -> 
      topic.writeUInt8(255, 0)
      topic.writeUInt8(127, 3)
      assert.equal topic[0], 255
      assert.equal topic[3], 127
    
    "it should write 16-bit integers with big endian encoding": (topic) -> 
      topic.writeUInt16((1 << 8) | 2, 2) # default endian = big
      assert.equal topic[2], 1
      assert.equal topic[3], 2

    "it should write 16-bit integers with big endian encoding": (topic) -> 
      topic.writeUInt16((1 << 8) | 2, 2, 'little') # default offset == 0
      assert.equal topic[2], 2
      assert.equal topic[3], 1
    
    "it should write 32-bit integers with big endian encoding": (topic) ->
      topic.writeUInt32(16909060, 0, 'big')
      assert.equal topic[0], 1
      assert.equal topic[1], 2
      assert.equal topic[2], 3
      assert.equal topic[3], 4

    "it should write 32-bit integers with little endian encoding": (topic) ->
      topic.writeUInt32(16909060, 0, 'little')
      assert.equal topic[0], 4
      assert.equal topic[1], 3
      assert.equal topic[2], 2
      assert.equal topic[3], 1

  "reading zero-terminated strings":
    topic: -> new Buffer([80,0,80,80,0])

    "it should read a string at the beginning of the buffer": (topic) ->
      assert.equal topic.readZeroTerminatedString(0), 'P'

    "it should read a string in the middle of the buffer": (topic) ->
      assert.equal topic.readZeroTerminatedString(2), 'PP'


  "reading unsigned integers":
    topic: -> new Buffer([1,2,3,4])
    
    "it should read 8-bit integers from the correct location": (topic) ->
      assert.equal topic.readUInt8(0), 1
      assert.equal topic.readUInt8(1), 2
      assert.equal topic.readUInt8(2), 3
      assert.equal topic.readUInt8(3), 4

    "it should read 16-bit big endian integers correctly": (topic) ->
      assert.equal topic.readUInt16(0, 'big'),    (1 << 8) + 2

    "it should read 16-bit little endian integers correctly": (topic) ->
      assert.equal topic.readUInt16(0, 'little'), (2 << 8) + 1

    "it should read 32-bit big endian integers correctly": (topic) ->
      assert.equal topic.readUInt32(0, 'big'), 16909060

    "it should read 32-bit little endian integers correctly": (topic) ->
      assert.equal topic.readUInt32(0, 'little'), 67305985

vow.export(module)
