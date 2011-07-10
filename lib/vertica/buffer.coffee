# This module backports some methods for the native Buffer class from Node 0.5.0
# The will only be overwritten if they do not exist.

Buffer = require('buffer').Buffer

Buffer::writeUInt8 ?= (number, offset, endian) ->
  @[offset || 0] = number & 0xff
  return 1

Buffer::writeUInt32 ?= (number, offset, endian) ->
  offset ?= 0
  encodingPositions = if endian == 'little' then [offset .. (offset + 3)] else [(offset + 3) .. offset]
  
  for currentOffset, index in encodingPositions
    @[currentOffset] = (number >> (8 * index)) & 0xff
    
  return 4
  
Buffer::readUInt8 ?= (offset, endian) ->
  @[offset || 0]

Buffer::readUInt32 ?= (offset, endian) ->
  offset ?= 0
  encodingPositions = if endian == 'little' then [offset .. (offset + 3)] else [(offset + 3) .. offset]
  
  number = 0
  for currentOffset, index in encodingPositions
    number = (@[currentOffset] <<  (index * 8)) | number

  return number

exports.Buffer = Buffer