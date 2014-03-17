assert = require 'assert'
Buffer = require('../../src/buffer').Buffer

describe 'Buffer', ->
  describe '#writeZeroTerminatedString', ->
    it "should write a zero terminated string correctly", ->
      topic = new Buffer([1,1,1,1,1])
      topic.writeZeroTerminatedString('test', 0)
      assert.deepEqual topic, new Buffer([116, 101, 115, 116, 0])

  describe '#readZeroTerminatedString', ->
    it "should read a string at the beginning of the buffer", ->
      topic = new Buffer([80,0,80,80,0])
      assert.equal topic.readZeroTerminatedString(0), 'P'

    it "should read a string in the middle of the buffer", ->
      topic = new Buffer([80,0,80,80,0])
      assert.equal topic.readZeroTerminatedString(2), 'PP'
