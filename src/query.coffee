EventEmitter    = require('events').EventEmitter
FrontendMessage = require('./frontend_message')
decoders        = require('./types').decoders
Resultset       = require('./resultset')

class Query extends EventEmitter

  constructor: (@connection, @sql, @callback) ->
    @_handlingCopyIn = false

  run: () ->
    @emit 'start'

    @connection._writeMessage(new FrontendMessage.Query(@sql))

    @connection.once 'EmptyQueryResponse', @onEmptyQueryListener      = @onEmptyQuery.bind(this)
    @connection.on   'RowDescription',     @onRowDescriptionListener  = @onRowDescription.bind(this)
    @connection.on   'DataRow',            @onDataRowListener         = @onDataRow.bind(this)
    @connection.on   'CommandComplete',    @onCommandCompleteListener = @onCommandComplete.bind(this)
    @connection.once 'ErrorResponse',      @onErrorResponseListener   = @onErrorResponse.bind(this)
    @connection.once 'ReadyForQuery',      @onReadyForQueryListener   = @onReadyForQuery.bind(this)
    @connection.once 'CopyInResponse',     @onCopyInResponseListener  = @onCopyInResponse.bind(this)

  onEmptyQuery: ->
    if @callback
      @error = "The query was empty!"
    else
      @emit 'error', "The query was empty!"

  onRowDescription: (msg) ->
    throw new Error("Cannot handle multi-queries with a callback!") if @callback? && @status?

    # custom decoders may override the default buffer decoders
    customDecoders = {}
    for type, decoder of @connection.connectionOptions.decoders
      # use any connection specific decoders
      customDecoders[type] = decoder
    for type, decoder of @decoders
      # query specific decoders take precedence over all other decoders
      customDecoders[type] = decoder

    @fields = []
    for column in msg.columns
      field = new Query.Field(column, customDecoders)
      @emit 'field', field
      @fields.push field

    @rows = [] if @callback
    @emit 'fields', @fields

  onDataRow: (msg) ->
    row = []
    for value, index in msg.values
      row.push if value? then @fields[index].decoder(value) else null

    @rows.push row if @callback
    @emit 'row', row

  onReadyForQuery: (msg) ->
    @_removeAllListeners()
    if @callback
      process.nextTick =>
        if @error
          @callback(@error)
        else
          @callback(null, new Resultset(fields: @fields, rows: @rows, status: @status))

  onCommandComplete: (msg) ->
    @status = msg.status if @callback
    @emit 'end', msg.status

  onErrorResponse: (msg) ->
    if @callback
      @error = msg
    else
      @emit 'error', msg.message

  onConnectionError: (msg) ->
    @_removeAllListeners()
    if @callback
      process.nextTick => @callback(msg)
    else
      @emit 'error', msg

  onCopyInResponse: (msg) ->
    @_handlingCopyIn = true
    dataHandler    = (data) => @copyData(data)
    successHandler = () => @copyDone()
    failureHandler = (err) => @copyFail(err)

    try
      copyInHandler = @_getCopyInHandler()
      copyInHandler(dataHandler, successHandler, failureHandler)
    catch err
      @copyFail(err)


  _getCopyInHandler: ->
    if typeof @copyInSource == 'function'
      return @copyInSource

    else if typeof @copyInSource == 'string' # copy from file
      fs = require('fs')
      existsSync = fs.existsSync || require('path').existsSync
      if existsSync(@copyInSource)
        stream = fs.createReadStream(@copyInSource)
        @_getStreamCopyInHandler(stream)
      else
        throw new Error("Could not find local file #{@copyInSource}.")

    else if @copyInSource == process.stdin # copy from STDIN
      process.stdin.resume()
      @_getStreamCopyInHandler(process.stdin)

    # if it looks like a stream... 
    else if typeof @copyInSource is 'object' and typeof @copyInSource.read is 'function' and typeof @copyInSource.push is 'function'
      @_getStreamCopyInHandler(@copyInSource)
    else
      throw new Error("No copy in handler defined to handle the COPY statement.")


  _getStreamCopyInHandler: (stream) ->
    (transfer, success, fail) ->
      stream.on 'data',  (data) -> transfer(data)
      stream.on 'end',   ()     -> success()
      stream.on 'error', (err)  -> fail(err)


  copyData: (data) ->
    if @_handlingCopyIn
      @connection._writeMessage(new FrontendMessage.CopyData(data))
    else
      throw new Error("Copy in mode not active!")

  copyDone: () ->
    if @_handlingCopyIn
      @connection._writeMessage(new FrontendMessage.CopyDone())
      @_handlingCopyIn = false
    else
      throw new Error("Copy in mode not active!")

  copyFail: (error) ->
    if @_handlingCopyIn
      message = error.message ? error.toString()
      @connection._writeMessage(new FrontendMessage.CopyFail(message))
      @_handlingCopyIn = false
    else
      throw new Error("Copy in mode not active!")

  _removeAllListeners: () ->
    @connection.removeListener 'EmptyQueryResponse', @onEmptyQueryListener
    @connection.removeListener 'RowDescription',     @onRowDescriptionListener
    @connection.removeListener 'DataRow',            @onDataRowListener
    @connection.removeListener 'CommandComplete',    @onCommandCompleteListener
    @connection.removeListener 'ErrorResponse',      @onErrorResponseListener
    @connection.removeListener 'ReadyForQuery',      @onReadyForQueryListener
    @connection.removeListener 'CopyInResponse',     @onCopyInResponseListener

class Query.Field
  constructor: (msg, customDecoders) ->
    @name            = msg.name
    @tableOID        = msg.tableOID
    @tableFieldIndex = msg.tableFieldIndex
    @typeOID         = msg.typeOID
    @type            = msg.type
    @size            = msg.size
    @modifier        = msg.modifier
    @formatCode      = msg.formatCode

    if customDecoders
      # custom decoders have precedence
      decoder = customDecoders[@type] || customDecoders.default

    @decoder = decoder || decoders[@formatCode][@type] || decoders[@formatCode].default


module.exports = Query
