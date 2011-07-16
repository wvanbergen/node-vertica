exports.Connection = require('./connection')

exports.connect = (connectionOptions, callback) ->
  connection = new exports.Connection(connectionOptions)
  connection.connect(callback)
  return connection

