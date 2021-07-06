# Supporting 0.11+ and beyond environment
module.exports = (socket, options, cb) ->
  tls = require('tls')
  secureContext = tls.createSecureContext(options)

  if tls.TLSSocket
    secureSocket = new tls.TLSSocket(socket, { isServer: false, secureContext })
  else
    pair = tls.createSecurePair(sslcontext, false)
    secureSocket = pipe(pair, socket)

  secureSocket.on 'secure', ->
    verifyError = secureSocket.ssl.verifyError()

    if verifyError
      secureSocket.authorized = false
      secureSocket.authorizationError = verifyError
    else
      secureSocket.authorized = true

    cb() if cb
  
  secureSocket.authorized = false
  secureSocket._controlReleased = true

  onError = (e) ->
    secureSocket.emit('error', e) if (secureSocket._controlReleased)

  onClose = ->
    socket.removeListener('error', onError)
    socket.removeListener('close', onClose)

  socket.on 'error', onError
  socket.on 'close', onClose

  if tls.TLSSocket

    secureSocket.on '_tlsError', (e) =>
      console.log '_tlsError', e

    secureSocket._start();

  return secureSocket;


pipe = (pair, socket) =>
  pair.encrypted.pipe(socket)
  socket.pipe(pair.encrypted)

  pair.fd = socket.fd
  cleartext = pair.cleartext
  cleartext.socket = socket
  cleartext.encrypted = pair.encrypted

  return cleartext
