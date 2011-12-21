(function() {
  var pipe;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  module.exports = function(socket, options, cb) {
    var cleartext, pair, sslcontext;
    sslcontext = require('crypto').createCredentials(options);
    pair = require('tls').createSecurePair(sslcontext, false);
    cleartext = pipe(pair, socket);
    pair.on('secure', function() {
      var verifyError;
      verifyError = pair.ssl.verifyError();
      if (verifyError) {
        cleartext.authorized = false;
        cleartext.authorizationError = verifyError;
      } else {
        cleartext.authorized = true;
      }
      if (cb) {
        return cb();
      }
    });
    cleartext._controlReleased = true;
    return cleartext;
  };
  pipe = __bind(function(pair, socket) {
    var cleartext, onClose, onError;
    pair.encrypted.pipe(socket);
    socket.pipe(pair.encrypted);
    pair.fd = socket.fd;
    cleartext = pair.cleartext;
    cleartext.socket = socket;
    cleartext.encrypted = pair.encrypted;
    cleartext.authorized = false;
    onError = function(e) {
      if (cleartext._controlReleased) {
        return cleartext.emit('error', e);
      }
    };
    onClose = function() {
      socket.removeListener('error', onError);
      return socket.removeListener('close', onClose);
    };
    socket.on('error', onError);
    socket.on('close', onClose);
    return cleartext;
  }, this);
}).call(this);
