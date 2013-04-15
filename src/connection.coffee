util = require 'util'
net  = require 'net'

EventEmitter    = require('events').EventEmitter
FrontendMessage = require('./frontend_message')
BackendMessage  = require('./backend_message')
Authentication  = require('./authentication')
Query           = require('./query')

class Connection extends EventEmitter

  constructor: (@connectionOptions) ->
    @connectionOptions.host   ?= 'localhost'
    @connectionOptions.port   ?= 5433
    @connectionOptions.ssl    ?= 'optional'

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

    initialErrorHandler = (err) ->
      callback err
    @connection.on 'error', initialErrorHandler

    @connection.on 'connect', =>
      @connection.removeListener 'error', initialErrorHandler
      @connected = true
      @_bindEventListeners()

      if @connectionOptions.ssl
        @_writeMessage(new FrontendMessage.SSLRequest)
        @connection.once 'data', (buffer) =>
          if 'S' == buffer.toString('utf-8')
            sslOptions = key: @connectionOptions.sslKey, cert: @connectionOptions.sslCert, ca: @connectionOptions.sslCA
            conn = require('./starttls') @connection, sslOptions, =>
              if !conn.authorized && @connectionOptions.ssl == 'verified'
                conn.end()
                @disconnect()
                err = new Error(conn.authorizationError)
                if @connectedCallback then @connectedCallback(err.message) else @emit 'error', err
              else
                @emit 'warn', conn.authorizationError unless conn.authorized
                @connection = conn
                @_bindEventListeners()
                @_handshake()
          else if @connectionOptions.ssl == "optional"
            @_handshake()
          else
            err = new Error("The server does not support SSL connection")
            if @connectedCallback then @connectedCallback(err.message) else @emit 'error', err

      else
        @_handshake()

  _bindEventListeners: ->
    @connection.on 'close',   @_onClose.bind(this)
    @connection.on 'error',   @_onError.bind(this)
    @connection.on 'timeout', @_onTimeout.bind(this)

  disconnect: ->
    @_writeMessage(new FrontendMessage.Terminate())
    @connection.end()

  isSSL: ->
    @connection.pair? && @connection.encrypted?

  _scheduleJob: (job) ->
    if @busy
      @queue.push job
      @emit 'queuejob', job
    else
      @_runJob(job)

    return job

  _runJob: (job) ->
    throw "Connection is closed" unless @connected
    throw "Connection is busy" if @busy

    @busy = true
    @currentJob = job
    job.run()
    return job

  _processJobQueue: () ->
    if @queue.length > 0
      @_runJob(@queue.shift())
    else
      @emit 'ready', this

  query: (sql, callback) ->
    @_scheduleJob(new Query(this, sql, callback))

  _queryDirect: (sql, callback) ->
    @_runJob(new Query(this, sql, callback))

  copy: (sql, source, callback) ->
    q = new Query(this, sql, callback)
    q.copyInSource = source
    @_scheduleJob(q)

  _handshake: ->
    authenticationFailureHandler = (err) =>
      if @connectedCallback then @connectedCallback(err.message) else @emit 'error', err

    authenticationHandler = (msg) =>
      switch msg.method
        when Authentication.methods.OK
          @once 'ReadyForQuery', (msg) =>
            @removeListener 'ErrorResponse', authenticationFailureHandler
            @_initializeConnection()

        when Authentication.methods.CLEARTEXT_PASSWORD, Authentication.methods.MD5_PASSWORD
          @_writeMessage(new FrontendMessage.Password(@connectionOptions.password, msg.method, salt: msg.salt, user: @connectionOptions.user))
          @once 'Authentication', authenticationHandler

        else
          throw new Error("Autentication method #{msg.method} not supported.")

    @connection.on 'data', @_onData.bind(this)
    @_writeMessage(new FrontendMessage.Startup(@connectionOptions.user, @connectionOptions.database))

    @once 'ErrorResponse',  authenticationFailureHandler
    @once 'Authentication', authenticationHandler
    @on   'ParameterStatus', (msg) => @parameters[msg.name] = msg.value
    @on   'BackendKeyData',  (msg) => [@pid, @key] = [msg.pid, msg.key]

    @on   'ReadyForQuery', (msg) =>
      @busy = false
      @currentJob = false
      @transactionStatus = msg.transactionStatus

  _initializeConnection: () ->
    initializers = []
    unless @connectionOptions.skipInitialization
      initializers.push @_initializeInterrupt          if @connectionOptions.interruptible
      initializers.push @_initializeRoles              if @connectionOptions.role?
      initializers.push @_initializeSearchPath         if @connectionOptions.searchPath?
      initializers.push @_initializeTimezone           if @connectionOptions.timezone?
      initializers.push @connectionOptions.initializer if @connectionOptions.initializer?

    chain = @_initializationSuccess.bind(this)
    for initializer in initializers
      chain = initializer.bind(this, chain, @_initializationFailure.bind(this))

    chain()


  _initializeRoles: (next, fail) ->
    roles = if @connectionOptions.role instanceof Array then @connectionOptions.role else [@connectionOptions.role]
    @_queryDirect "SET ROLE #{roles.join(', ')}", (err, result) =>
      if err? then fail(err) else next()


  _initializeSearchPath: (next, fail) ->
    searchPath = if @connectionOptions.searchPath instanceof Array then @connectionOptions.searchPath else [@connectionOptions.searchPath]
    @_queryDirect "SET SEARCH_PATH TO #{searchPath.join(', ')}", (err, result) =>
      if err? then fail(err) else next()


  _initializeTimezone: (next, fail) ->
    @_queryDirect "SET TIMEZONE TO '#{@connectionOptions.timezone}'", (err, result) =>
      if err? then fail(err) else next()

  _initializeInterrupt: (next, fail) ->
    @_queryDirect "SELECT session_id FROM v_monitor.current_session", (err, result) =>
      if err? then fail(err)
      @sessionID = result.theValue()
      next()

  _initializationSuccess: ->
    @on 'ReadyForQuery', @_processJobQueue.bind(this)
    @_processJobQueue()
    @connectedCallback(null, this) if @connectedCallback

  _initializationFailure: (err) ->
    if @connectedCallback then @connectedCallback(err) else @emit 'error', err


  _onData: (buffer) ->
    # Append the new data with the previous buffer's residue if there was any.
    if @incomingData.length == 0
      @incomingData = buffer
    else
      bufferedData = new Buffer(@incomingData.length + buffer.length)
      @incomingData.copy(bufferedData)
      buffer.copy(bufferedData, @incomingData.length)
      @incomingData = bufferedData

    size = @incomingData.readUInt32(1) # start at 1 to skip the message ID
    while @incomingData.length >= 5 && size + 1 <= @incomingData.length

      # parse message
      message = BackendMessage.fromBuffer(@incomingData.slice(0, size + 1))
      console.log '<=', message.event, message if @debug
      @emit 'message', message
      @emit message.event, message

      # update loop variables
      @incomingData = @incomingData.slice(size + 1)
      size = @incomingData.readUInt32(1)

  _onClose: (error)->
    @currentJob.onConnectionError("The connection was closed.") if @currentJob
    @connected = false
    @emit 'close', error

  _onTimeout: () ->
    @currentJob.onConnectionError("The connection timed out closed.") if @currentJob
    @emit 'timeout'

  _onError: (exception) ->
    @emit 'error', exception

  _writeMessage: (msg, callback) ->
    console.log '=>', msg.__proto__.constructor.name, msg if @debug
    @connection.write(msg.toBuffer(), null, callback)

  isInterruptible: ->
    @sessionID?

  _interruptConnection: (cb) ->
    if @sessionID?
      bareConnectionOptions = { skipInitialization: true }
      bareConnectionOptions.__proto__ = @connectionOptions
      bareClient = new Connection(bareConnectionOptions)
      bareClient.connect(cb)
    else
      cb("Cannot interrupt connection! It's not initialized as interruptible.", null)

  _success: (err, cb) ->
    if err?
      if cb? then cb(err) else @emit 'error', new Error(err)
      return false
    else
      return true

  interruptSession: (cb) ->
    @_interruptConnection (err, conn) =>
      if @_success(err, cb)
        conn.query "SELECT CLOSE_SESSION('#{@sessionID}')", (err, rs) =>
          conn.disconnect()
          cb(null, rs.theValue()) if @_success(err, cb) && cb?


  interruptStatement: (cb) ->
    @_interruptConnection (err, conn) =>
      if @_success(err, cb)
        conn.query "SELECT statement_id FROM v_monitor.sessions WHERE session_id = '#{@sessionID}'", (err, rs) =>
          if !@_success(err, cb)
            conn.disconnect()
          else if rs.getLength() == 1 && statementID = rs.theValue()
            bareClient.query "SELECT INTERRUPT_STATEMENT('#{@sessionID}', statementID)", (err, rs) =>
              conn.disconnect()
              cb(null, rs.theValue()) if @_success(err, cb) && cb?
          else
            conn.disconnect()
            @_success("Session #{@sessionID} is not running a statement at the moment.", cb)


# Exports
module.exports = Connection
