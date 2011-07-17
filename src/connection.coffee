util = require 'util'
net  = require 'net'

EventEmitter    = require('events').EventEmitter
FrontendMessage = require('./frontend_message')
BackendMessage  = require('./backend_message')
Authentication  = require('./authentication')
Query           = require('./query')
 
class Connection extends EventEmitter
  
  constructor: (@connectionOptions) ->
    @connectionOptions.host   ||= 'localhost'
    @connectionOptions.port   ||= 5433
  
    @parameters = {}
    @key = null
    @pid = null
    @transactionStatus = null
    
    @incomingData = new Buffer(0)
  
  connect: (callback) ->
    @connectedCallback = callback
    @connection = net.createConnection @connectionOptions.port, @connectionOptions.host

    @connection.on 'connect', @_onConnect.bind(this)
    @connection.on 'data',    @_onData.bind(this)
    @connection.on 'close',   @_onClose.bind(this)
    @connection.on 'error',   @_onError.bind(this)
    @connection.on 'timeout', @_onTimeout.bind(this)


  disconnect: ->
    @connection.end()


  query: (sql, callback) ->
    q = new Query(this, sql)
    q.on 'error', (err) => console.error err
    return q


  _handshake: ->
    @_writeMessage(new FrontendMessage.Startup(@connectionOptions.user, @connectionOptions.database))

    authenticationHandler = (msg) =>
      switch msg.method 
        when Authentication.methods.OK
          @once 'ReadyForQuery', (msg) => @connectedCallback(this)
          
        when Authentication.methods.CLEARTEXT_PASSWORD, Authentication.methods.MD5_PASSWORD
          @_writeMessage(new FrontendMessage.Password(@connectionOptions.password, msg.method, salt: msg.salt, user: @connectionOptions.user))
          @once 'Authentication', authenticationHandler
          
        else
          throw new Error("Autentication method #{msg.method} not supported.")
    
    @once 'Authentication', authenticationHandler

    @on 'ReadyForQuery',   (msg) => @transactionStatus = msg.transactionStatus
    @on 'ParameterStatus', (msg) => @parameters[msg.name] = msg.value
    @on 'BackendKeyData',  (msg) => [@pid, @key] = [msg.pid, msg.key]



  _onConnect: ->
    if @connectionOptions.secure
      # TODO: secure
    else
      @_handshake()
    
  _onData: (buffer) ->
    # Append the new data with the previous buffer's residue if there was any.
    if @incomingData.length == 0
      @incomingData = buffer
    else
      bufferedData = new Buffer(@incomingData.length + buffer.length)
      @incomingData.copy(bufferedData)
      buffer.copy(bufferedData, @incomingData.length)
      @incomingData = bufferedData
    
    size = @incomingData.readUInt32(1) # skip the message ID
    while size + 1 <= @incomingData.length

      # parse message
      message = BackendMessage.fromBuffer(@incomingData.slice(0, size + 1))
      @emit 'message', message
      @emit message.event, message
      
      # update loop variables
      @incomingData = @incomingData.slice(size + 1)
      size = @incomingData.readUInt32(1)


  _onClose: ->
    @connected = false
    @emit 'close'
    
  _onTimeout: (exception) ->
    console.error util.inspect(exception)
    @emit 'timeout', exception
    
  _onError: (exception) ->
    console.error util.inspect(exception)
    @emit 'error', exception
    
  _writeMessage: (msg, callback) ->
    @connection.write(msg.toBuffer(), null, callback)

# Exports
module.exports = Connection
