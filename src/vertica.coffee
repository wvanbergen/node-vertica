exports.Connection = require('./connection')

exports.connect = (connectionOptions, callback) ->
  connection = new exports.Connection(connectionOptions)
  connection.connect(callback)
  return connection

exports.escape = (val) ->
  val.toString().replace(/'/g, "''")

exports.quote = (val) ->
  if !val?
    'NULL'
  else if val == true
    'TRUE'
  else if val == false
    'FALSE'
  else if typeof val == 'number'
    val.toString()
  else if typeof val == 'string'
    "'#{exports.escape(val)}'"
  else if val instanceof Array
    (exports.quote(v) for v in val).join(', ')
  else if val instanceof Date
    if exports.useLocalTimezone
      throw "Local dates are not yet supported!"
    else
      timestamp = val.toISOString().replace(/T/, ' ').replace(/\.\d+Z$/, '')
      "TIMESTAMP('#{timestamp}')"
  else 
    "'#{exports.escape(val)}'"

exports.quoteIdentifier = (val) ->
  '"' + val.toString().replace(/"/g, '""') + '"'

exports.useLocalTimezone = false
