Authentication  = require('./authentication')
Buffer          = require('./buffer').Buffer

###########################################
# Client messages
###########################################

class FrontendMessage
  typeId: null
  
  payload: ->
    new Buffer(0)
  
  toBuffer: ->
    payloadBuffer = @payload()
    if typeof payloadBuffer == 'string'
      b = new Buffer(payloadBuffer.length + 1)
      b.writeZeroTerminatedString(payloadBuffer, 0)
      payloadBuffer = b

    headerLength  = if @typeId? then 5 else 4
    messageBuffer = new Buffer(headerLength + payloadBuffer.length)
    
    if @typeId
      messageBuffer.writeUInt8(@typeId, 0)
      pos = 1
    else 
      pos = 0

    messageBuffer.writeUInt32(payloadBuffer.length + 4, pos)
    payloadBuffer.copy(messageBuffer, pos + 4)
    
    return messageBuffer


class FrontendMessage.Startup extends FrontendMessage
  typeId: null
  protocol: 3 << 16
  
  constructor: (@user, @database, @options) ->
    
  payload: ->
    pos = 0
    pl = new Buffer(8192)
    pl.writeUInt32(@protocol, pos)
    pos += 4

    if @user
      pos += pl.writeZeroTerminatedString('user', pos)
      pos += pl.writeZeroTerminatedString(@user,  pos)

    if @database
      pos += pl.writeZeroTerminatedString('database', pos)
      pos += pl.writeZeroTerminatedString(@database,  pos)

    if @options
      pos += pl.writeZeroTerminatedString('options', pos)
      pos += pl.writeZeroTerminatedString(@options,  pos)
    
    pl.writeUInt8(0, pos)
    pos += 1
    return pl.slice(0, pos)
    
    
class FrontendMessage.SSLRequest extends FrontendMessage
  typeId: null
  sslMagicNumber: 80877103
  
  payload: ->
    pl = new Buffer(4)
    pl.writeUInt32(@sslMagicNumber, 0)
    return pl
    
class FrontendMessage.Password extends FrontendMessage
  typeId: 112

  constructor: (@password, @authMethod, @options) -> 
    @password   ?= ''
    @authMethod ?= Authentication.methods.CLEARTEXT_PASSWORD
    @options    ?= {}

  md5: (str) ->
    hash = require('crypto').createHash('md5')
    hash.update(str)
    hash.digest('hex')

  encodedPassword: ->
    switch @authMethod 
      when Authentication.methods.CLEARTEXT_PASSWORD then @password
      when Authentication.methods.MD5_PASSWORD then "md5" + @md5(@md5(@password + @options.user) + @options.salt) 
      else throw new Error("Authentication method #{@authMethod} not implemented.")

  payload: ->
    @encodedPassword()


class FrontendMessage.CancelRequest extends FrontendMessage
  cancelRequestMagicNumber: 80877102
  
  constructor: (@backendPid, @backendKey) ->
  
  payload: ->
    b = new Buffer(12)
    b.writeUInt32(@cancelRequestMagicNumber, 0)
    b.writeUInt32(@backendPid, 4)
    b.writeUInt32(@backendKey, 8)
    return b

class FrontendMessage.Close extends FrontendMessage
  typeId: 67

  constructor: (type, @name) ->
    @name ?= ""
    @type = switch type
      when 'portal', 'p', 'P', 80 then 80
      when 'prepared_statement', 'prepared', 'statement', 's', 'S', 83 then 83
      else throw new Error("#{type} not a valid type to describe")

  payload: ->
    b = new Buffer(@name.length + 2)
    b.writeUInt8(@type, 0)
    b.writeZeroTerminatedString(@name, 1)
    return b


class FrontendMessage.Describe extends FrontendMessage
  typeId: 68

  constructor: (type, @name) ->
    @name ?= ""
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
class FrontendMessage.Execute extends FrontendMessage
  typeId: 69

  constructor: (@portal, @maxRows) ->
    @portal  ?= ""
    @maxRows ?= 0
    
    
  payload: ->
    b = new Buffer(5 + @portal.length)
    pos = b.writeZeroTerminatedString(@portal, 0)
    b.writeUInt32(@maxRows, pos)
    return b


class FrontendMessage.Query extends FrontendMessage
  typeId: 81

  constructor: (@sql) ->

  payload: ->
    @sql

class FrontendMessage.Parse extends FrontendMessage
  typeId: 80
    
  constructor: (@name, @sql, @parameterTypes) ->
    @name ?= ""
    @parameterTypes ?= []

  payload: ->
    b = new Buffer(8192)
    pos  = b.writeZeroTerminatedString(@name, 0)
    pos += b.writeZeroTerminatedString(@sql, pos)

    b.writeUInt16(@parameterTypes.length, pos)
    pos += 2
    for paramType in @parameterTypes
      b.writeUInt32(paramType, pos)
      pos += 4

    return b.slice(0, pos)


class FrontendMessage.Bind extends FrontendMessage
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
    b.writeUInt16(0x00, pos) # encode values using text
    b.writeUInt16(@parameterValues.length, pos + 2)
    pos += 4

    for value in @parameterValues
      b.writeUInt32(value.length, pos)
      pos += 4
      pos += b.write(value, pos)

    return b.slice(0, pos)


class FrontendMessage.Flush extends FrontendMessage
  typeId: 72


class FrontendMessage.Sync extends FrontendMessage
  typeId: 83


class FrontendMessage.Terminate extends FrontendMessage
  typeId: 88


class FrontendMessage.CopyData extends FrontendMessage
  typeId: 100
  
  constructor: (@data) ->
    
  payload: ->
    new Buffer(@data)


class FrontendMessage.CopyDone extends FrontendMessage
  typeId: 99


class FrontendMessage.CopyFail extends FrontendMessage
  typeId: 102

  constructor: (@error) ->
    
  payload: ->
    @error


module.exports = FrontendMessage
