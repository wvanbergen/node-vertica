
module.exports = (socket, options, cb) ->
  sslcontext = require('crypto').createCredentials(options)
  pair       = require('tls').createSecurePair(sslcontext, false)
  cleartext  = pipe(pair, socket)

  pair.on 'secure', ->
    verifyError = pair.ssl.verifyError()

    if verifyError
      cleartext.authorized = false
      cleartext.authorizationError = verifyError
    else
      cleartext.authorized = true

    cb() if cb

  cleartext._controlReleased = true
  return cleartext;


pipe = (pair, socket) =>
  pair.encrypted.pipe(socket)
  socket.pipe(pair.encrypted)

  pair.fd = socket.fd
  cleartext = pair.cleartext
  cleartext.socket = socket
  cleartext.encrypted = pair.encrypted
  cleartext.authorized = false

  onError = (e) -> 
    cleartext.emit('error', e) if (cleartext._controlReleased)
  
  onClose = ->
    socket.removeListener('error', onError)
    socket.removeListener('close', onClose)

  socket.on 'error', onError
  socket.on 'close', onClose

  return cleartext
