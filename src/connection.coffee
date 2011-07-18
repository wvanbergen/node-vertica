util = require 'util'
net  = require 'net'
fs   = require 'fs'

EventEmitter    = require('events').EventEmitter
FrontendMessage = require('./frontend_message')
BackendMessage  = require('./backend_message')
Authentication  = require('./authentication')
Query           = require('./query')
 
class Connection extends EventEmitter
  
  constructor: (@connectionOptions) ->
    @connectionOptions.host   ||= 'localhost'
    @connectionOptions.port   ||= 5433
  
    @connected = false
    @busy      = true
    @queue     = []
    
    @parameters = {}
    @key = null
    @pid = null
    @transactionStatus = null
    
    @incomingData = new Buffer(0)
  
  connect: (callback) ->
    @connectedCallback = callback
    @connection = net.createConnection @connectionOptions.port, @connectionOptions.host
    
    @connection.on 'connect', =>
      @connected = true
      @_bindEventListeners()
      
      if @connectionOptions.ssl
        @_writeMessage(new FrontendMessage.SSLRequest)
        @connection.once 'data', (buffer) =>
          if 'S' == buffer.toString('utf-8')
            tls      = require 'tls'
            starttls = require './starttls'
            
            sslOptions = key: @connectionOptions.key, cert: @connectionOptions.cert, ca: @connectionOptions.ca
            sslOptions.key ?= fs.readFileSync("#{__dirname}/../res/default-client-key.pem")
            
            conn = starttls @connection, sslOptions, =>
              if !conn.authorized && @connectionOptions.rejectUnauthorized
                conn.end()
                @disconnect()
                @emit 'error', new Error(conn.authorizationError)
              else
                @emit 'warn', conn.authorizationError unless conn.authorized
                @connection = conn
                @_bindEventListeners()
                @_handshake()
              
          else if @connectionOptions.ssl == true || @connectionOptions.ssl == 'required'
            @emit 'error', new Error("The server does not support SSL connection")
          else 
            @_handshake()
      else
        @_handshake()

  _bindEventListeners: ->
    @connection.on 'close',   @_onClose.bind(this)
    @connection.on 'error',   @_onError.bind(this)
    @connection.on 'timeout', @_onTimeout.bind(this)

  disconnect: ->
    @connection.end()

  _schedule: (job) ->
    if @busy
      @queue.push job
      @emit 'queue', job
    else
      job.execute()
      
    return job
    

  query: (sql, callback) ->
    @_schedule(new Query(this, sql, callback))


  _handshake: ->
    @connection.on 'data', @_onData.bind(this)
    @_writeMessage(new FrontendMessage.Startup(@connectionOptions.user, @connectionOptions.database))

    authenticationHandler = (msg) =>
      switch msg.method 
        when Authentication.methods.OK
          @once 'ReadyForQuery', (msg) => 
            @busy = false
            @connectedCallback(this)
          
        when Authentication.methods.CLEARTEXT_PASSWORD, Authentication.methods.MD5_PASSWORD
          @_writeMessage(new FrontendMessage.Password(@connectionOptions.password, msg.method, salt: msg.salt, user: @connectionOptions.user))
          @once 'Authentication', authenticationHandler
          
        else
          throw new Error("Autentication method #{msg.method} not supported.")

    @once 'Authentication', authenticationHandler
    @on 'ParameterStatus', (msg) => @parameters[msg.name] = msg.value
    @on 'BackendKeyData',  (msg) => [@pid, @key] = [msg.pid, msg.key]
    
    @on 'ReadyForQuery',   (msg) => 
      @transactionStatus = msg.transactionStatus
      if @queue.length > 0
        job = @queue.shift()
        @emit 'dequeue', job
        job.execute()
      else
        @emit 'ready', this


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
      console.log @incomingData.slice(0, size + 1)
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
    
  _onTimeout: () ->
    @emit 'timeout'
    
  _onError: (exception) ->
    @emit 'error', exception
    
  _writeMessage: (msg, callback) ->
    @connection.write(msg.toBuffer(), null, callback)

# Exports
module.exports = Connection
