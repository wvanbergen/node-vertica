exports.Connection = require('./connection')

exports.connect = (connectionOptions, callback) ->
  connection = new exports.Connection(connectionOptions)
  connection.connect(callback)
  return connection

exports.setTimezoneOffset = (offset) ->
  if !offset?
    exports.timezoneOffset = null
  else if matches = offset.match(/^([\+\-])(\d{1,2})(?:\:(\d{2}))?$/)
    timezoneOffset = +matches[2] * 60 + (+matches[3] || 0)
    timezoneOffset = 0 - timezoneOffset if matches[1] == '-'
    exports.timezoneOffset = timezoneOffset * 60 * 1000
  else
    throw "Invalid timezone offset string: #{offset}!"


types   = require('./types')
quoting = require('./quoting')

exports.Date            = types.Date
exports.Time            = types.Time
# exports.Timestamp       = types.Timestamp
exports.Interval        = types.Interval

exports.escape          = quoting.escape
exports.quote           = quoting.quote
exports.quoteIdentifier = quoting.quoteIdentifier
