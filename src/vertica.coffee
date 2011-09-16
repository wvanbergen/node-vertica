exports.Connection = require('./connection')

exports.connect = (connectionOptions, callback) ->
  connection = new exports.Connection(connectionOptions)
  connection.connect(callback)
  return connection

exports.Resultset = require('./resultset')

types   = require('./types')

exports.Date              = types.Date
exports.Time              = types.Time
exports.Timestamp         = types.Timestamp
exports.Interval          = types.Interval
exports.setTimezoneOffset = types.Timestamp.setTimezoneOffset

quoting = require('./quoting')

exports.escape          = quoting.escape
exports.quote           = quoting.quote
exports.quoteIdentifier = quoting.quoteIdentifier
