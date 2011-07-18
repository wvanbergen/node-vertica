EventEmitter    = require('events').EventEmitter
OutgoingMessage = require('./frontend_message')

class Query extends EventEmitter
  
  constructor: (@connection, @sql, @callback) ->
    
  execute: () ->
    @emit 'start'
    
    @rows = [] if @callback
    @connection._writeMessage(new OutgoingMessage.Query(@sql))
    
    @connection.once 'EmptyQueryResponse', @onEmptyQueryListener      = @onEmptyQuery.bind(this)
    @connection.on   'RowDescription',     @onRowDescriptionListener  = @onRowDescription.bind(this)
    @connection.on   'DataRow',            @onDataRowListener         = @onDataRow.bind(this)
    @connection.on   'CommandComplete',    @onCommandCompleteListener = @onCommandComplete.bind(this)
    @connection.once 'ErrorResponse',      @onErrorResponseListener   = @onErrorResponse.bind(this)
    @connection.once 'ReadyForQuery',      @onReadyForQueryListener   = @onReadyForQuery.bind(this)


  onEmptyQuery: ->
    @emit 'error', "The query was empty!"
    @callback("The query was empty!") if @callback
  
  onRowDescription: (msg) ->
    @fields = []
    for column in msg.columns
      field = new Query.Field(column)
      @emit 'field', field
      @fields.push field

    @emit 'fields', @fields
    
  onDataRow: (msg) ->
    row = []
    for value, index in msg.values
      row.push if value? then @fields[index].convert(value) else null
    
    @rows.push row if @callback
    @emit 'row', row
    
  onReadyForQuery: (msg) ->
    @_removeAllListeners()

  onCommandComplete: (msg) ->
    @emit 'end', msg.status
    @callback(null, @fields, @rows, msg.status) if @callback
    @rows = [] if @callback
    
  onErrorResponse: (msg) ->
    @_removeAllListeners()
    @emit 'error', msg
    @callback(msg.message) if @callback

  _removeAllListeners: () ->
    @connection.removeListener 'EmptyQueryResponse', @onEmptyQueryListener
    @connection.removeListener 'RowDescription',     @onRowDescriptionListener
    @connection.removeListener 'DataRow',            @onDataRowListener
    @connection.removeListener 'CommandComplete',    @onCommandCompleteListener
    @connection.removeListener 'ErrorResponse',      @onErrorResponseListener
    @connection.removeListener 'ReadyForQuery',      @onReadyForQueryListener


stringConverters =
  string:   (value) -> value.toString()
  integer:  (value) -> parseInt(value)
  float:    (value) -> parseValue(value)
  bool:     (value) -> value.toString() == 't'
  
  datetime: (value) ->
    year   = parseInt(value.slice(0, 4))
    month  = parseInt(value.slice(5, 7))
    day    = parseInt(value.slice(8, 10))
    hour   = parseInt(value.slice(11, 13))
    minute = parseInt(value.slice(14, 16))
    second = parseInt(value.slice(17, 19))
    new Date(Date.UTC(year, month, day, hour, minute, second))
    
  date: (value) ->
    year   = parseInt(value.slice(0, 4))
    month  = parseInt(value.slice(5, 7))
    day    = parseInt(value.slice(8, 10))
    new Date(Date.UTC(year, month, day))

  default: (value) -> value.toString()


binaryConverters =
  default: (value) -> value.toString()


fieldConverters =
  0: stringConverters
  1: binaryConverters


class Query.Field
  constructor: (msg) ->
    @name            = msg.name
    @tableId         = msg.tableId
    @tableFieldIndex = msg.tableFieldIndex
    @typeId          = msg.typeId
    @type            = msg.type
    @size            = msg.size
    @modifier        = msg.modifier
    @formatCode      = msg.formatCode
    
    @convert = fieldConverters[@formatCode][@type] || fieldConverters[@formatCode].default


module.exports = Query
