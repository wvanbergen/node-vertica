class VerticaError extends Error {
  constructor(message) {
    super(message)
  }
}

class ConnectionError extends VerticaError {
  constructor(message) {
    super(message)
  }
}

class ConnectionErrorResponse extends ConnectionError {
  constructor(errorResponse) {
    super(errorResponse.information['Message'])
    this.fields = errorResponse.information
    this.code = errorResponse.information['Code']
  }
}

class AuthenticationError extends ConnectionErrorResponse {
  constructor(errorResponse) {
    super(errorResponse)
  }
}

class SSLError extends ConnectionError {
  constructor(message) {
    super(message)
  }
}

class ClientStateError extends VerticaError {
  constructor(message) {
    super(message)
  }
}

class QueryError extends VerticaError {
  constructor(message) {
    super(message)
  }
}

class QueryErrorResponse extends QueryError {
  constructor(errorResponse) {
    super(errorResponse.information['Message'])
    this.fields = errorResponse.information
    this.code = errorResponse.information['Code']
  }
}

export { VerticaError, ConnectionError, ConnectionErrorResponse, AuthenticationError, SSLError, ClientStateError, QueryError, QueryErrorResponse }
