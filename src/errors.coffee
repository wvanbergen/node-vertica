class exports.VerticaError extends Error
  constructor: (@message) ->
    super(@message)

class exports.ConnectionError extends exports.VerticaError
class exports.ConnectionErrorResponse extends exports.ConnectionError
  constructor: (msg) ->
    super(msg.information['Message'])
    @fields = msg.information
    @code = msg.information['Code']

class exports.AuthenticationError extends exports.ConnectionErrorResponse

class exports.SSLError extends exports.ConnectionError
class exports.ClientStateError extends exports.VerticaError
class exports.QueryError extends exports.VerticaError

class exports.QueryErrorResponse extends exports.QueryError
  constructor: (msg) ->
    super(msg.information['Message'])
    @fields = msg.information
    @code = msg.information['Code']
