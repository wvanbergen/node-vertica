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


class IncomingMessage.ErrorResponse extends IncomingMessage
  typeId: 69 # E
  
  fieldNames:
    83:  'Severity'
    67:  'Code'
    77:  'Message'
    68:  'Detail'
    72:  'Hint'
    80:  'Position'
    112: 'Internal position'
    113: 'Internal query'
    87:  'Where'
    70:  'File'
    76:  'Line'
    82:  'Routine'
    
  read: (buffer) ->
    @information = {}
    
    fieldCode = buffer.readUInt8(0)
    pos = 1
    while fieldCode != 0x00
      value = buffer.readZeroTerminatedString(pos)
      @information[@fieldNames[fieldCode] || fieldCode] = value
      pos += Buffer.byteLength(value) + 1
      
      fieldCode = buffer.readUInt8(pos)
      pos += 1


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
  typeId = buffer.readUInt8()
  messageClass = IncomingMessage.types[typeId]
  if messageClass?
    message = new messageClass(buffer.slice(5))
    message
  else
    throw new Error("Unkown message type: #{typeId}")
  
module.exports = IncomingMessage
