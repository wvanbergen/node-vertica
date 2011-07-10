util = require('util')
net  = require('net')

EventEmitter    = require('events').EventEmitter
OutgoingMessage = require('./outgoing_message')
IncomingMessage = require('./incoming_message')
Authentication  = require('./authentication')

class Connection extends EventEmitter
  
  constructor: (@connectionOptions) ->
    @connectionOptions.host   ||= 'localhost'
    @connectionOptions.port   ||= 5433
  
    @parameters = {}
    @key = null
    @pid = null
    @transactionStatus = null
  
  connect: (callback) ->
    @connectedCallback = callback
    @connection = net.createConnection @connectionOptions.port, @connectionOptions.host

    @connection.on 'connect', @_onConnect.bind(this)
    @connection.on 'data',    @_onData.bind(this)
    @connection.on 'close',   @_onClose.bind(this)
    @connection.on 'error',   @_onError.bind(this)
    @connection.on 'timeout', @_onTimeout.bind(this)

    
  query: (sql) ->
    @_writeMessage(new OutgoingMessage.Query(sql))

  _onConnect: ->
    # TODO: secure
    @_writeMessage(new OutgoingMessage.Startup(@connectionOptions.user, @connectionOptions.database))

    parameterHandler = (msg) => @parameters[msg.name] = msg.value
    keydataHandler   = (msg) => [@pid, @key] = [msg.pid, msg.key]
    readyHandler     = (msg) => 
      @removeListener 'ParameterStatus', parameterHandler
      @removeListener 'BackendKeyData', keydataHandler
      @connectedCallback(this)
      
    handler = (msg) =>
      switch msg.method 
        when Authentication.methods.OK
          @on 'ParameterStatus', parameterHandler
          @on 'BackendKeyData',  keydataHandler
          @once 'ReadyForQuery', readyHandler
          
        when Authentication.methods.CLEARTEXT_PASSWORD, Authentication.methods.MD5_PASSWORD
          @_writeMessage(new OutgoingMessage.Password(@connectionOptions.password, msg.method, salt: msg.salt, user: @connectionOptions.user))
          @once 'Authentication', handler
          
        else
          throw new Error("Autentication method #{msg.method} not supported.")
    
    @once 'Authentication', handler

    @on 'ReadyForQuery', (msg) =>
      @transactionStatus = msg.transactionStatus
    
  _onData: (buffer) ->
    buffer._pos = 0
    while buffer._pos < buffer.length
      message = IncomingMessage.fromBuffer(buffer)
      @emit 'message', message
      @emit message.event, message
    
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
