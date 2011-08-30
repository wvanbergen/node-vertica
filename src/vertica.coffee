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


exports.setTimezoneOffset = (offset) ->
  if !offset?
    exports.timezoneOffset = null
  else if matches = offset.match(/^([\+\-])(\d{1,2})(?:\:(\d{2}))?$/)
    timezoneOffset = +matches[2] * 60 + (+matches[3] || 0)
    timezoneOffset = 0 - timezoneOffset if matches[1] == '-'
    exports.timezoneOffset = timezoneOffset * 60 * 1000
  else
    throw "Invalid timezone offset string: #{offset}!"
