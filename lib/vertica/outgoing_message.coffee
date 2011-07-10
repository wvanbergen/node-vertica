Authentication  = require('./authentication')
Buffer          = require('./buffer').Buffer

###########################################
# Client messages
###########################################

class OutgoingMessage
  typeId: null
  
  payload: ->
    new Buffer(0)
  
  toBuffer: ->
    payloadBuffer = @payload()

    if typeof payloadBuffer == 'string'
      b = new Buffer(payloadBuffer.length + 1)
      b.writeZeroTerminatedString(payloadBuffer)
      payloadBuffer = b
      
    headerLength = if @typeId? then 5 else 4
    pos = 0
    messageBuffer = new Buffer(headerLength + payloadBuffer.length)

    pos += messageBuffer.writeUInt8(@typeId, pos) if @typeId
    pos += messageBuffer.writeUInt32(payloadBuffer.length + 4, pos)
    payloadBuffer.copy(messageBuffer, pos)
    
    return messageBuffer


class OutgoingMessage.Startup extends OutgoingMessage
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
    
    
class OutgoingMessage.SSLRequest extends OutgoingMessage
  typeId: null
  sslMagicNumber: 80877103
  
  payload: ->
    pl = new Buffer(4)
    pl.writeUInt32(@sslMagicNumber)
    return pl
    
class OutgoingMessage.Password extends OutgoingMessage
  typeId: 112

  constructor: (@password, @authMethod, @options) -> 
    @authMethod ?= Authentication.methods.CLEARTEXT_PASSWORD
    @options    ?= {}

  md5: (str) ->
    hash = require('crypto').createHash('md5')
    hash.update(str)
    hash.digest('hex')

  encodedPassword: ->
    switch  @authMethod 
      when Authentication.methods.CLEARTEXT_PASSWORD then @password
      when Authentication.methods.MD5_PASSWORD then "md5" + @md5(@md5(@password + @options.user) + @options.salt) 
      else throw new Error("Authentication method #{@authMethod} not implemented.")

  payload: ->
    @encodedPassword()


class OutgoingMessage.CancelRequest extends OutgoingMessage
  cancelRequestMagicNumber: 80877102
  
  constructor: (@backendPid, @backendKey) ->
  
  payload: ->
    b = new Buffer(12)
    b.writeUInt32(@cancelRequestMagicNumber, 0)
    b.writeUInt32(@backendPid, 4)
    b.writeUInt32(@backendKey, 8)
    return b

class OutgoingMessage.Close extends OutgoingMessage
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


class OutgoingMessage.Describe extends OutgoingMessage
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
class OutgoingMessage.Execute extends OutgoingMessage
  typeId: 69

  constructor: (@portal, @maxRows) ->

  payload: ->
    b = new Buffer(5 + @portal.length)
    pos = b.writeZeroTerminatedString(@portal)
    b.writeUInt32(@maxRows, pos)
    return b


class OutgoingMessage.Query extends OutgoingMessage
  typeId: 81

  constructor: (@sql) ->

  payload: ->
    @sql

class OutgoingMessage.Parse extends OutgoingMessage
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


class OutgoingMessage.Bind extends OutgoingMessage
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

class OutgoingMessage.Flush extends OutgoingMessage
  typeId: 72

class OutgoingMessage.Sync extends OutgoingMessage
  typeId: 83

class OutgoingMessage.Terminate extends OutgoingMessage
  typeId: 88


module.exports = OutgoingMessage