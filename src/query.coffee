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
    @emit 'error', "The query was empty!" unless @callback
    @callback("The query was empty!") if @callback
  
  onRowDescription: (msg) ->
    throw "Cannot handle multi-queries with a callback!" if @callback? && @status?
    
    @fields = []
    for column in msg.columns
      field = new Query.Field(column)
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
    @callback(null, new Resultset(fields: @fields, rows: @rows, status: @status)) if @callback
    @_removeAllListeners()

  onCommandComplete: (msg) ->
    @status = msg.status if @callback
    @emit 'end', msg.status

  onErrorResponse: (msg) ->
    @_removeAllListeners()
    @emit 'error', msg.message unless @callback
    @callback(msg) if @callback

  onCopyInResponse: (msg) ->
    @_handlingCopyIn = true
    dataHandler    = (data) => @copyData(data)
    successHandler = () => @copyDone()
    failureHandler = (err) => @copyFail(err)
    
    copyInHandler = @_getCopyInHandler()
    copyInHandler(dataHandler, successHandler, failureHandler)
    
  _getCopyInHandler: ->
    if typeof @copyInSource == 'function'
      return @copyInSource

    else if typeof @copyInSource == 'string' # copy from file
      if require('path').existsSync(@copyInSource)
        stream = require('fs').createReadStream(@copyInSource)
        @_getStreamCopyInHandler(stream)
      else
        @copyFail("Could not find local file #{@dataSource}.")

    else if @copyInSource == process.stdin # copy from STDIN
      process.stdin.resume()
      @_getStreamCopyInHandler(process.stdin)

    else
      throw "No copy in handler defined to handle the COPY statement."


  _getStreamCopyInHandler: (stream) ->
    (transfer, success, fail) ->
      stream.on 'data',  (data) -> transfer(data)
      stream.on 'end',   ()     -> success()
      stream.on 'error', (err)  -> fail(err)


  copyData: (data) ->
    if @_handlingCopyIn
      @connection._writeMessage(new FrontendMessage.CopyData(data))
    else
      throw "Copy in mode not active!"

  copyDone: () ->
    if @_handlingCopyIn
      @connection._writeMessage(new FrontendMessage.CopyDone())
      @_handlingCopyIn = false
    else
      throw "Copy in mode not active!"

  copyFail: (error) ->
    if @_handlingCopyIn
      @connection._writeMessage(new FrontendMessage.CopyFail(error.toString()))
      @_handlingCopyIn = false
    else
      throw "Copy in mode not active!"

  _removeAllListeners: () ->
    @connection.removeListener 'EmptyQueryResponse', @onEmptyQueryListener
    @connection.removeListener 'RowDescription',     @onRowDescriptionListener
    @connection.removeListener 'DataRow',            @onDataRowListener
    @connection.removeListener 'CommandComplete',    @onCommandCompleteListener
    @connection.removeListener 'ErrorResponse',      @onErrorResponseListener
    @connection.removeListener 'ReadyForQuery',      @onReadyForQueryListener
    @connection.removeListener 'CopyInResponse',     @onCopyInResponseListener

class Query.Field
  constructor: (msg) ->
    @name            = msg.name
    @tableOID        = msg.tableOID
    @tableFieldIndex = msg.tableFieldIndex
    @typeOID         = msg.typeOID
    @type            = msg.type
    @size            = msg.size
    @modifier        = msg.modifier
    @formatCode      = msg.formatCode

    @decoder = decoders[@formatCode][@type] || decoders[@formatCode].default


module.exports = Query
