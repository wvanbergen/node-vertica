VerticaConnection = require('./vertica/connection')

exports.connect = (connectionOptions, callback) ->
  connection = new VerticaConnection(connectionOptions)
  connection.connect(callback)
  return connection
