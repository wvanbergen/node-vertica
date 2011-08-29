EventEmitter    = require('events').EventEmitter
OutgoingMessage = require('./frontend_message')
ValueDecorders  = require('./value_decoders')

class Query extends EventEmitter
  
  constructor: (@connection, @sql, @callback) ->
    
  execute: () ->
    @emit 'start'

    @connection._writeMessage(new OutgoingMessage.Query(@sql))
    
    @connection.once 'EmptyQueryResponse', @onEmptyQueryListener      = @onEmptyQuery.bind(this)
    @connection.on   'RowDescription',     @onRowDescriptionListener  = @onRowDescription.bind(this)
    @connection.on   'DataRow',            @onDataRowListener         = @onDataRow.bind(this)
    @connection.on   'CommandComplete',    @onCommandCompleteListener = @onCommandComplete.bind(this)
    @connection.once 'ErrorResponse',      @onErrorResponseListener   = @onErrorResponse.bind(this)
    @connection.once 'ReadyForQuery',      @onReadyForQueryListener   = @onReadyForQuery.bind(this)


  onEmptyQuery: ->
    @emit 'error', "The query was empty!" unless @callback
    @callback("The query was empty!") if @callback
  
  onRowDescription: (msg) ->
    throw "Cannot handle muti-queries with a callback!" if @callback? && @status?
    
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
      console.log value.toString('utf8')
      process.stdout.write ("#{byte}" for byte in value).join(", ")
      process.stdout.write("\n")
      row.push if value? then @fields[index].convert(value) else null
    
    @rows.push row if @callback
    @emit 'row', row
    
  onReadyForQuery: (msg) ->
    @callback(null, @fields, @rows, @status) if @callback
    @_removeAllListeners()

  onCommandComplete: (msg) ->
    @status = msg.status if @callback
    @emit 'end', msg.status

    
  onErrorResponse: (msg) ->
    @_removeAllListeners()
    @emit 'error', msg unless @callback
    @callback(msg.message) if @callback

  _removeAllListeners: () ->
    @connection.removeListener 'EmptyQueryResponse', @onEmptyQueryListener
    @connection.removeListener 'RowDescription',     @onRowDescriptionListener
    @connection.removeListener 'DataRow',            @onDataRowListener
    @connection.removeListener 'CommandComplete',    @onCommandCompleteListener
    @connection.removeListener 'ErrorResponse',      @onErrorResponseListener
    @connection.removeListener 'ReadyForQuery',      @onReadyForQueryListener


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
    
    @convert = ValueDecorders[@formatCode][@type] || ValueDecorders[@formatCode].default


module.exports = Query
