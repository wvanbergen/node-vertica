AuthenticationMethods  = require('./authentication').methods

class IncomingMessage
  typeId: null
  
  constructor: (buffer) ->
    @read(buffer)
  
  read: (buffer) ->
    # Implement me in subclass


class IncomingMessage.Authentication extends IncomingMessage
  typeId: 82 # R
  
  read: (buffer) ->
    @method = buffer.readUInt32(0)
    if @method == AuthenticationMethods.MD5_PASSWORD
      @salt = stream.readUInt32(4)
    else if @method == AuthenticationMethods.CRYPT_PASSWORD
      @salt = stream.readUInt16(4)


class IncomingMessage.BackendKeyData extends IncomingMessage
  typeId: 75 # K

  read: (buffer) ->
    @pid = buffer.readUInt32(0)
    @key = buffer.readUInt32(4)


class IncomingMessage.ParameterStatus extends IncomingMessage
  typeId: 83 # S

  read: (buffer) ->
    @name  = buffer.readZeroTerminatedString(0)
    @value = buffer.readZeroTerminatedString(@name.length + 1)
    

class IncomingMessage.RowDescription extends IncomingMessage
  typeId: 84 # T
  
  read: (buffer) ->
    numberOfFields = buffer.readUInt16(0)
    pos = 2

    @columns = []
    for i in [0 ... numberOfFields]
      name = buffer.readZeroTerminatedString(pos)
      pos += Buffer.byteLength(name) + 1
      tableId = buffer.readUInt32(pos)
      pos += 4
      fieldIndex = buffer.readUInt16(pos)
      pos += 2
      type = buffer.readUInt32(pos)
      pos += 4
      size = buffer.readUInt16(pos)
      pos += 2
      modifier = buffer.readUInt32(pos)
      pos += 4
      formatCode = buffer.readUInt16(pos)
      pos += 2
      
      @columns.push name: name, tableId: tableId, fieldIndex: fieldIndex, type: type, size: size, modifier: modifier, formatCode: formatCode


class IncomingMessage.DataRow extends IncomingMessage
  typeId: 68 # D
  
  read: (buffer) ->
    numberOfFields = buffer.readUInt16(0)
    pos = 2

    @values = []
    for i in [0 ... numberOfFields]
      length = buffer.readUInt32(pos)
      pos += 4

      if length == -1
        data = null
      else
        data = buffer.slice(pos, pos + length)
        pos += length
      
      @values.push(data)
    
  
class IncomingMessage.CommandComplete extends IncomingMessage
  typeId: 67 # C
  
  read: (buffer) ->
    @status = buffer.readZeroTerminatedString()


class IncomingMessage.ReadyForQuery extends IncomingMessage
  typeId: 90 # Z
  
  read: (buffer) ->
    @transactionStatus = buffer.readUInt8(0)
  
##############################################################
# IncomingMessage factory
############################################################## 

IncomingMessage.types = {}
for name, messageClass of IncomingMessage
  if messageClass.prototype && messageClass.prototype.typeId?
    messageClass.prototype.event = name
    IncomingMessage.types[messageClass.prototype.typeId] = messageClass


IncomingMessage.fromBuffer = (buffer) ->
  buffer._pos ?= 0
  
  typeId = buffer.readUInt8(buffer._pos + 0)
  size   = buffer.readUInt32(buffer._pos + 1)

  messageClass = IncomingMessage.types[typeId]
  if messageClass?
    message = new messageClass(buffer.slice(buffer._pos + 5, buffer._pos + size + 1))
    buffer._pos += 1 + size
    message
  else
    throw new Error("Unkown message type: #{typeId}")
  
module.exports = IncomingMessage
