Buffer = require('./buffer').Buffer

class Message
  endian: 'big'

  zeroTerminatedString: (str) ->
    "#{str}\0"

  zeroTerminatedStringBuffer: (str) ->
    buffer = new Buffer(Buffer.byteLength(str) + 1)
    buffer.write(str)
    buffer[buffer.length - 1] = 0
    return buffer

###########################################
# Server messages
###########################################

class Message.Server extends Message
  read: (buffer) ->
    # Implement me in subclass

class Message.Server.ReadyForQuery extends Message.Server
  typeId: 90

###########################################
# Client messages
###########################################

class Message.Client extends Message
  typeId: null
  
  payload: ->
    new Buffer(0)
  
  toBuffer: ->
    payloadBuffer = @payload()
    payloadBuffer = @zeroTerminatedStringBuffer(payloadBuffer) if typeof payloadBuffer == 'string'
      
    headerLength = if @typeId? then 5 else 4
    pos = 0
    messageBuffer = new Buffer(headerLength + payloadBuffer.length)

    pos += messageBuffer.writeUInt8(@typeId, pos, Message.endian) if @typeId
    pos += messageBuffer.writeUInt32(payloadBuffer.length + 4, pos, Message.endian)
    payloadBuffer.copy(messageBuffer, pos)
    
    return messageBuffer


class Message.Client.Startup extends Message.Client
  typeId: null
  protocol: 3 << 16
  
  constructor: (@user, @database, @options) ->
    
  payload: ->
    pos = 0
    pl = new Buffer(8192)
    pos += pl.writeUInt32(@protocol, pos)

    if @user
      pos += pl.writeZeroTerminatedString('user', pos)
      pos += pl.writeZeroTerminatedString(@user,  pos)

    if @database
      pos += pl.writeZeroTerminatedString('database', pos)
      pos += pl.writeZeroTerminatedString(@database,  pos)

    if @options
      pos += pl.writeZeroTerminatedString('options', pos)
      pos += pl.writeZeroTerminatedString(@options,  pos)

    pos += pl.writeUInt8(0, pos) # FIXME: 0 or '0' ??
    return pl.slice(0, pos)
    
    
class Message.Client.SSLRequest extends Message.Client
  typeId: null
  sslMagicNumber: 80877103
  
  payload: ->
    pl = new Buffer(4)
    pl.writeUInt32(@sslMagicNumber)
    return pl
    
class Message.Client.Password extends Message.Client
  typeId: 112

  authMethods :
    OK: 0
    KERBEROS_V5: 2
    CLEARTEXT_PASSWORD: 3
    CRYPT_PASSWORD: 4
    MD5_PASSWORD: 5
    SCM_CREDENTIAL: 6
    GSS: 7
    GSS_CONTINUE: 8
    SSPI: 9

  constructor: (@password, @authMethod, @options) -> 
    @authMethod ?= @authMethods.CLEARTEXT_PASSWORD
    @options    ?= {}

  md5: (str) ->
    hash = require('crypto').createHash('md5')
    hash.update(str)
    hash.digest('hex')

  encodedPassword: ->
    if @authMethod == @authMethods.CLEARTEXT_PASSWORD
      @password
    else if @authMethod == @authMethods.MD5_PASSWORD
      # TODO: check if this is actually implemented and working like this
      "md5" + @md5(@md5(@password + @options.user) + @options.salt) 
    else
      throw new Error("Authentication method #{@authMethod} not implemented.")

  payload: ->
    @encodedPassword()


class Message.Client.CancelRequest extends Message.Client
  cancelRequestMagicNumber: 80877102
  
  constructor: (@backendPid, @backendKey) ->
  
  payload: ->
    b = new Buffer(12)
    b.writeUInt32(@cancelRequestMagicNumber, 0)
    b.writeUInt32(@backendPid, 4)
    b.writeUInt32(@backendKey, 8)
    return b

class Message.Client.Close extends Message.Client
  typeId: 67

  constructor: (type, @name) ->
    @type = switch type
      when 'portal', 'P', 80 then 80
      when 'prepared_statement', 'prepared', 'statement', 'S', 83 then 83
      else throw new Error("#{type} not a valid type to describe")

  payload: ->
    b = new Buffer(@name.length + 2)
    b.writeUInt8(@type, 0)
    b.writeZeroTerminatedString(@name, 1)
    return b


class Message.Client.Describe extends Message.Client
  typeId: 68

  constructor: (type, @name) ->
    @type = switch type
      when 'portal', 'P', 80 then 80
      when 'prepared_statement', 'prepared', 'statement', 'S', 83 then 83
      else throw new Error("#{type} not a valid type to describe")

  payload: ->
    b = new Buffer(@name.length + 2)
    b.writeUInt8(@type, 0)
    b.writeZeroTerminatedString(@name, 1)
    return b

# EXECUTE (E=69)
class Message.Client.Execute extends Message.Client
  typeId: 69

  constructor: (@portal, @maxRows) ->

  payload: ->
    b = new Buffer(5 + @portal.length)
    pos = b.writeZeroTerminatedString(@portal)
    b.writeUInt32(@maxRows, pos)
    return b


class Message.Client.Query extends Message.Client
  typeId: 81

  constructor: (@sql) ->

  payload: ->
    @sql

class Message.Client.Parse extends Message.Client
  typeId: 80
    
  constructor: (@name, @sql, @parameterTypes) ->

  payload: ->
    b = new Buffer(8192)
    pos  = b.writeZeroTerminatedString(@name, pos)
    pos += b.writeZeroTerminatedString(@sql, pos)

    pos += b.writeUInt16(@parameterTypes.length, pos)
    for paramType in @parameterTypes
      pos += b.writeUInt32(paramType, pos)

    return b.slice(0, pos)


class Message.Client.Bind extends Message.Client
  typeId: 66
  
  constructor: (@portal, @preparedStatement, parameterValues) ->
    @parameterValues = []
    for parameterValue in parameterValues
      @parameterValues.push parameterValue.toString()
  
  payload: ->
    b = new Buffer(8192)
    pos = 0
    
    pos += b.writeZeroTerminatedString(@portal, pos)
    pos += b.writeZeroTerminatedString(@preparedStatement, pos)
    pos += b.writeUInt16(0x00, pos) # encode values using text
    pos += b.writeUInt16(@parameterValues.length, pos)
    
    for value in @parameterValues
      pos += b.writeUInt32(value.length, pos)
      pos += b.write(value, pos)
        
    return b.slice(0, pos)

class Message.Client.Flush extends Message.Client
  typeId: 72

class Message.Client.Sync extends Message.Client
  typeId: 83

class Message.Client.Terminate extends Message.Client
  typeId: 88

###########################################
# Reading messages
###########################################

Message.types = {}
for _, messageClass of Message.Server
  if messageClass.typeId != undefined
    Message.types[messageClass.typeId] = messageClass

  
Message.fromBuffer = (buffer) ->
  typeId = buffer.readUInt8  0, Message.endian
  size   = buffer.readUInt32 1, Message.endian
  
  messageClass = Message.types[typeId]
  messageClass.read(buffer.slice(5, 5 + size))

# exports
module.exports = Message
