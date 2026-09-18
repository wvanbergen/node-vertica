util = require 'util'
net  = require 'net'

EventEmitter    = require('events').EventEmitter
FrontendMessage = require('./frontend_message')
BackendMessage  = require('./backend_message')
Authentication  = require('./authentication')
Query           = require('./query')
errors          = require('./errors')

class Connection extends EventEmitter

  constructor: (@connectionOptions) ->
    @connectionOptions.host        ?= 'localhost'
    @connectionOptions.port        ?= 5433
    @connectionOptions.ssl         ?= 'optional'
    @connectionOptions.keepAlive   ?= false

    @connected = false
    @closing = false
    @closed = false
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

    initialErrorHandler = (err) =>
      @_onError(err)

    @connection.once 'close', @_onClose.bind(this)
    @connection.on 'error', initialErrorHandler

    @connection.on 'connect', =>
      return if @closing
      @connection.removeListener 'error', initialErrorHandler
      @connected = true
      @_bindEventListeners()

      if @connectionOptions.keepAlive
        @connection.setKeepAlive true

      if @connectionOptions.ssl
        @_writeMessage(new FrontendMessage.SSLRequest)
        @connection.once 'data', (buffer) =>
          if 'S' == buffer.toString('utf-8')
            sslOptions = key: @connectionOptions.sslKey, cert: @connectionOptions.sslCert, ca: @connectionOptions.sslCA
            conn = require('./starttls') @connection, sslOptions, =>
              if !conn.authorized && @connectionOptions.ssl == 'verified'
                conn.end()
                @disconnect()
                err = new errors.SSLError(conn.authorizationError)
                @_initializationFailure(err)
              else
                @emit 'warn', conn.authorizationError unless conn.authorized
                @connection = conn
                @_bindEventListeners()
                @_handshake()
          else if @connectionOptions.ssl == "optional"
            @_handshake()
          else
            err = new errors.SSLError("The server does not support SSL connection")
            @_initializationFailure(err)

      else
        @_handshake()

  _bindEventListeners: ->
    @connection.once 'close',   @_onClose.bind(this) if @connection.encrypted
    @connection.once 'error',   @_onError.bind(this)
    @connection.once 'timeout', @_onTimeout.bind(this)

  disconnect: (error) ->
    return if @closing
    wasConnected = @connected
    @closing = true
    @connected = false
    try
      @_writeMessage(new FrontendMessage.Terminate()) if wasConnected
    finally
      @connection.end() if @connection
      @_failJobs(error ? new errors.ConnectionError("The connection was closed."))

  # Abort an abandoned operation without waiting for the server to finish it.
  # The close event, not this call, confirms that the transport has closed.
  destroy: (error) ->
    @closing = true
    @connected = false
    @connection.destroy() if @connection
    @_failJobs(error ? new errors.ConnectionError("The connection was closed."))

  _finishConnect: (err) ->
    callback = @connectedCallback
    @connectedCallback = null
    if callback
      callback(err, if err then null else this)
      return true
    false

  _failJobs: (error) ->
    jobs = @queue.splice(0)
    jobs.unshift(@currentJob) if @currentJob
    @currentJob = false
    @busy = false
    # Mark jobs terminal immediately; each job defers its user notification.
    job.onConnectionError(error) for job in jobs

  isSSL: ->
    @connection.pair? && @connection.encrypted?

  _scheduleJob: (job) ->
    if @closing
      process.nextTick -> job.onConnectionError(new errors.ConnectionError("The connection was closed."))
      return job
    if @busy
      @queue.push job
      @emit 'queuejob', job
    else
      @_runJob(job)

    return job

  _runJob: (job) ->
    throw new errors.ClientStateError("Connection is closed") unless @connected
    throw new errors.ClientStateError("Connection is busy") if @busy

    @busy = true
    @currentJob = job
    job.run()
    return job

  _processJobQueue: () ->
    return if @closing
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
      err = new errors.AuthenticationError(err)
      @_initializationFailure(err)

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
          throw new errors.ClientStateError("Authentication method #{msg.method} not supported.")

    @connection.on 'data', @_onData.bind(this)
    @_writeMessage(new FrontendMessage.Startup(@connectionOptions.user, @connectionOptions.database))

    @once 'ErrorResponse',  authenticationFailureHandler
    @once 'Authentication', authenticationHandler
    @on   'ParameterStatus', (msg) => @parameters[msg.name] = msg.value
    @on   'BackendKeyData',  (msg) => [@pid, @key] = [msg.pid, msg.key]

    @on   'ReadyForQuery', (msg) =>
      return if @closing
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
    return if @closing
    @on 'ReadyForQuery', @_processJobQueue.bind(this)
    @_processJobQueue()
    @_finishConnect(null)

  _initializationFailure: (err) ->
    @destroy(err)
    @emit 'error', err unless @_finishConnect(err)


  _onData: (buffer) ->
    # Append the new data with the previous buffer's residue if there was any.
    if @incomingData.length == 0
      @incomingData = buffer
    else
      bufferedData = new Buffer(@incomingData.length + buffer.length)
      @incomingData.copy(bufferedData)
      buffer.copy(bufferedData, @incomingData.length)
      @incomingData = bufferedData


     # start at 1 to skip the message ID
    while @incomingData.length >= 5
      size = @incomingData.readUInt32BE(1)

      if size + 1 <= @incomingData.length
        # parse message
        message = BackendMessage.fromBuffer(@incomingData.slice(0, size + 1))
        console.log '<=', message.event, message if @debug
        @emit 'message', message
        @emit message.event, message

        # update loop variables
        @incomingData = @incomingData.slice(size + 1)
      else
        # message fragmented, keep collecting
        break

    # explicit return to avoid coffeescript generating result array
    undefined

  _onClose: () ->
    return if @closed
    @closed = true
    @closing = true
    @connected = false
    error = new errors.ConnectionError("The connection was closed.")
    @_failJobs(error)
    @_finishConnect(error)
    @emit 'close'

  _onTimeout: () ->
    error = new errors.ConnectionError("The connection timed out.")
    @destroy(error)
    @_finishConnect(error)
    @emit 'timeout'

  _onError: (err) ->
    error = new errors.ConnectionError(err.message ? err.toString())
    @destroy(error)
    @emit 'error', error unless @_finishConnect(error)

  _writeMessage: (msg, callback) ->
    console.log '=>', msg.__proto__.constructor.name, msg if @debug
    @connection.write(msg.toBuffer(), callback)

  isInterruptible: ->
    @sessionID?

  _interruptConnection: (cb) ->
    if @sessionID?
      bareConnectionOptions = { skipInitialization: true }
      bareConnectionOptions.__proto__ = @connectionOptions
      bareClient = new Connection(bareConnectionOptions)
      bareClient.connect(cb)
    else
      cb(new errors.ClientStateError("Cannot interrupt connection! It's not initialized as interruptible."), null)

  _success: (err, cb) ->
    if err?
      if cb? then cb(err) else @emit 'error', err
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
            conn.query "SELECT INTERRUPT_STATEMENT('#{@sessionID}', #{statementID})", (err, rs) =>
              conn.disconnect()
              cb(null, rs.theValue()) if @_success(err, cb) && cb?
          else
            conn.disconnect()
            @_success("Session #{@sessionID} is not running a statement at the moment.", cb)


# Exports
module.exports = Connection
