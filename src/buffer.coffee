# This module backports some methods for the native Buffer class from Node 0.5.0
# The will only be overwritten if they do not exist.

Buffer = require('buffer').Buffer

#######################################
# Writing integers
#######################################

Buffer::writeUInt8 ?= (number, offset) ->
  @[offset] = number & 0xff
  return undefined

Buffer::writeUInt16 ?= (number, offset, endian) ->
  @_writeUInt(2, number, offset, endian)

Buffer::writeUInt32 ?= (number, offset, endian) ->
  @_writeUInt(4, number, offset, endian)
  
Buffer::_writeUInt ?= (bytes, number, offset, endian) ->
  encodingPositions = if endian == 'little' then [offset .. (offset + bytes - 1)] else [(offset + bytes - 1) .. offset]

  for currentOffset, index in encodingPositions
    @[currentOffset] = (number >> (8 * index)) & 0xff
  
  return undefined
  
#######################################
# Writing strings
#######################################

Buffer::writeZeroTerminatedString ?= (str, offset, encoding) ->
  written = @write(str, offset, null, encoding)
  @writeUInt8(0, offset + written)
  return written + 1
  
#######################################
# Reading ints
#######################################

Buffer::readUInt8 ?= (offset) ->
  @[offset]

Buffer::readUInt16 ?= (offset, endian) ->
  @_readUInt(2, offset, endian)

Buffer::readUInt32 ?= (offset, endian) ->
  @_readUInt(4, offset, endian)

Buffer::_readUInt ?= (bytes, offset, endian) ->
  encodingPositions = if endian == 'little' then [offset .. (offset + bytes - 1)] else [(offset + bytes - 1) .. offset]
  
  number = 0
  for currentOffset, index in encodingPositions
    number = (@[currentOffset] <<  (index * 8)) | number

  return number

#######################################
# Reading strings
#######################################

Buffer::readZeroTerminatedString ?= (offset, encoding) ->
  endIndex = offset
  endIndex++ while endIndex < @length && @[endIndex] != 0x00
  return @toString('ascii', offset, endIndex)


#######################################
# Debugging
#######################################

# Buffer.debug ?= (buffer) ->
#   bytes = ("#{byte}" for byte in buffer).join(", ")
#   "Buffer([#{bytes}])"


exports.Buffer = Buffer