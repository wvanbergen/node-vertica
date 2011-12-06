AuthenticationMethods = require('./authentication').methods
typeOIDs = require('./types').typeOIDs

class BackendMessage
  typeId: null
  
  constructor: (buffer) ->
    @read(buffer)
  
  read: (buffer) ->
    # Implement me in subclass


class BackendMessage.Authentication extends BackendMessage
  typeId: 82 # R
  
  read: (buffer) ->
    @method = buffer.readUInt32(0)
    if @method == AuthenticationMethods.MD5_PASSWORD
      @salt = stream.readUInt32(4)
    else if @method == AuthenticationMethods.CRYPT_PASSWORD
      @salt = stream.readUInt16(4)


class BackendMessage.BackendKeyData extends BackendMessage
  typeId: 75 # K

  read: (buffer) ->
    @pid = buffer.readUInt32(0)
    @key = buffer.readUInt32(4)


class BackendMessage.ParameterStatus extends BackendMessage
  typeId: 83 # S

  read: (buffer) ->
    @name  = buffer.readZeroTerminatedString(0)
    @value = buffer.readZeroTerminatedString(@name.length + 1)


class BackendMessage.NotificationResponse extends BackendMessage
  typeId: 65 # A
  
  read: (buffer) ->
    @pid = buffer.readUInt32(4)
    @channel = buffer.readZeroTerminatedString(4)
    @payload = buffer.readZeroTerminatedString(@channel.length + 5)


class BackendMessage.EmptyQueryResponse extends BackendMessage
  typeId: 73 # I


class BackendMessage.RowDescription extends BackendMessage
  typeId: 84 # T
  
  read: (buffer) ->
    numberOfFields = buffer.readUInt16(0)
    pos = 2

    @columns = []
    for i in [0 ... numberOfFields]
      name = buffer.readZeroTerminatedString(pos)
      pos += Buffer.byteLength(name) + 1
      tableOID = buffer.readUInt32(pos)
      pos += 4
      tableFieldIndex = buffer.readUInt16(pos)
      pos += 2
      typeOID = buffer.readUInt32(pos)
      pos += 4
      size = buffer.readUInt16(pos)
      pos += 2
      modifier = buffer.readUInt32(pos)
      pos += 4
      formatCode = buffer.readUInt16(pos)
      pos += 2


      fieldDescriptor = 
        name: name
        tableOID: tableOID
        tableFieldIndex: tableFieldIndex
        typeOID: typeOID
        type: typeOIDs[typeOID]
        size: size
        modifier: modifier
        formatCode: formatCode

      @columns.push fieldDescriptor


class BackendMessage.DataRow extends BackendMessage
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
    
  
class BackendMessage.CommandComplete extends BackendMessage
  typeId: 67 # C
  
  read: (buffer) ->
    @status = buffer.readZeroTerminatedString(0)


class BackendMessage.CloseComplete extends BackendMessage
  typeId: 51 # 3


class BackendMessage.ParameterDescription extends BackendMessage
  typeId: 116 # t

  read: (buffer) ->
    count = buffer.readUInt16(0)
    @parameterTypes = (buffer.readUInt32(2 + i * 4) for i in [0 ... count])


class BackendMessage.ParseComplete extends BackendMessage
  typeId: 49 # 1


class BackendMessage.ErrorResponse extends BackendMessage
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

    @message = @information['Message']

class BackendMessage.NoticeResponse extends BackendMessage.ErrorResponse
  typeId: 78 # N


class BackendMessage.ReadyForQuery extends BackendMessage
  typeId: 90 # Z

  read: (buffer) ->
    @transactionStatus = buffer.readUInt8(0)

class BackendMessage.CopyInResponse extends BackendMessage
  typeId: 71 # G

  read: (buffer) ->
    @globalFormatType = buffer.readUInt8(0)
    @fieldFormatTypes = []

    numberOfFields = buffer.readUInt16(1)
    pos = 3
    for i in [0 ... numberOfFields]
      @fieldFormatTypes.push buffer.readUInt8(pos)
      pos += 1


##############################################################
# BackendMessage factory
############################################################## 

BackendMessage.types = {}
for name, messageClass of BackendMessage
  if messageClass.prototype && messageClass.prototype.typeId?
    messageClass.prototype.event = name
    BackendMessage.types[messageClass.prototype.typeId] = messageClass


BackendMessage.fromBuffer = (buffer) ->
  typeId = buffer.readUInt8(0)
  messageClass = BackendMessage.types[typeId]
  if messageClass?
    message = new messageClass(buffer.slice(5))
    message
  else
    throw new Error("Unkown message type: #{typeId}")


module.exports = BackendMessage
