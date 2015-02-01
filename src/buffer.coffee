Buffer = require('buffer').Buffer

Buffer::writeZeroTerminatedString = (str, offset, encoding) ->
  written = @write(str, offset, encoding)
  @writeUInt8(0, offset + written)
  return written + 1

Buffer::readZeroTerminatedString = (offset, encoding) ->
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
