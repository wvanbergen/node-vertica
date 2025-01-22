import net from 'node:net'
import EventEmitter from 'node:events'

import { SSLError, ConnectionError,ClientStateError, AuthenticationError } from './errors.js'
import { Query } from './query.js'
import { FrontendMessage } from './frontend_message.js'
import { ParseMessageFromBuffer } from './backend_message.js'
import { AuthenticationMethods } from './authentication.js';
import { startTLS } from './starttls.js';

class Connection extends EventEmitter {
  connected = false
  busy = true
  queue = []
  parameters = {}
  key = null
  pid = null
  transactionStatus = null
  incomingData = Buffer.alloc(0)
  debug = false 

  constructor(connectionOptions) {
    super()

    this.connectionOptions = connectionOptions || {}
    this.connectionOptions.host ??= 'localhost'
    this.connectionOptions.port ??= 5433
    this.connectionOptions.ssl ??= 'optional'
    this.connectionOptions.keepalive ??= false
    this.debug = connectionOptions.debug || false;
  }

  connect(callback) {
    this.connectedCallback = callback;
    this.connection = net.createConnection(this.connectionOptions.port, this.connectionOptions.host);

    const initialErrorHandler = (err) => {
      if (this.connectedCallback) {
        return this.connectedCallback(err.message);
      } else {
        return this.emit('error', err);
      }
    }

    this.connection.on('error', initialErrorHandler);

    this.connection.on('connect', () => {
      this.connection.removeListener('error', initialErrorHandler);
      this.connected = true;
      this._bindEventListeners();
      if (this.connectionOptions.keepAlive) {
        this.connection.setKeepAlive(true);
      }
      if (this.connectionOptions.ssl) {
        this.writeMessage(new FrontendMessage.SSLRequest);
        this.connection.once('data', function(buffer) {
          var conn, err, sslOptions;
          if ('S' === buffer.toString('utf-8')) {
            sslOptions = {
              key: this.connectionOptions.sslKey,
              cert: this.connectionOptions.sslCert,
              ca: this.connectionOptions.sslCA
            };

            return conn = startTLS(this.connection, sslOptions, () => {
              var err;
              if (!conn.authorized && this.connectionOptions.ssl === 'verified') {
                conn.end();
                this.disconnect();
                err = new SSLError(conn.authorizationError);
                if (this.connectedCallback) {
                  this.connectedCallback(err);
                } else {
                  this.emit('error', err);
                }
              } else {
                if (!conn.authorized) {
                  this.emit('warn', conn.authorizationError);
                }
                this.connection = conn;
                this._bindEventListeners();
                handshake();
              }
            })
          } else if (this.connectionOptions.ssl === "optional") {
            this._handshake();
          } else {
            err = new SSLError("The server does not support SSL connection");
            if (this.connectedCallback) {
              this.connectedCallback(err);
            } else {
              this.emit('error', err);
            }
          }
        });
      } else {
        this._handshake();
      }
    })
  }

  _bindEventListeners() {
    this.connection.once('close', this._onClose.bind(this));
    this.connection.once('error', this._onError.bind(this));
    return this.connection.once('timeout', this._onTimeout.bind(this));
  }

  disconnect(error) {
    if (error) {
      this._onError(error);
    }
    if (this.connection.connected) {
      this.writeMessage(new FrontendMessage.Terminate());
    }
    return this.connection.end();
  }

  isSSL() {
    return (this.connection.pair != null) && (this.connection.encrypted != null);
  }

  #scheduleJob(job) {
    if (this.busy) {
      this.queue.push(job);
      this.emit('queuejob', job);
    } else {
      this.#runJob(job);
    }
    return job;
  }

  #runJob(job) {
    if (!this.connected) {
      throw new ClientStateError("Connection is closed");
    }
    if (this.busy) {
      throw new ClientStateError("Connection is busy");
    }
    this.busy = true;
    this.currentJob = job;
    job.run();
    return job;
  }

  _processJobQueue() {
    if (this.queue.length > 0) {
      return this.#runJob(this.queue.shift());
    } else {
      return this.emit('ready', this);
    }
  }

  query(sql, callback) {
    return this.#scheduleJob(new Query(this, sql, callback));
  }

  _queryDirect(sql, callback) {
    return this.#runJob(new Query(this, sql, callback));
  }

  copy(sql, source, callback) {
    var q;
    q = new Query(this, sql, callback);
    q.copyInSource = source;
    return this.#scheduleJob(q);
  }

  _handshake() {
    const authenticationFailureHandler = (err) => {
      err = new AuthenticationError(err);
      if (this.connectedCallback) {
        this.connectedCallback(err);
      } else {
        this.emit('error', err);
      }
    }

    const authenticationHandler = (msg) => {
      switch (msg.method) {
        case AuthenticationMethods.OK:
            return this.once('ReadyForQuery', function(msg) {
              this.removeListener('ErrorResponse', authenticationFailureHandler);
              this._initializeConnection();
            });
        case AuthenticationMethods.CLEARTEXT_PASSWORD:
        case AuthenticationMethods.MD5_PASSWORD:
          this.writeMessage(new FrontendMessage.Password(this.connectionOptions.password, msg.method, {
            salt: msg.salt,
            user: this.connectionOptions.user
          }));
          this.once('Authentication', authenticationHandler);
        default:
          throw new ClientStateError("Authentication method " + msg.method + " not supported.");
      }
    }

    this.connection.on('data', this._onData.bind(this));
    this.writeMessage(new FrontendMessage.Startup(this.connectionOptions.user, this.connectionOptions.database));

    this.once('ErrorResponse', authenticationFailureHandler);
    this.once('Authentication', authenticationHandler);
    this.on('ParameterStatus', (msg) => {
      this.parameters[msg.name] = msg.value;
    })

    this.on('BackendKeyData', (msg) => {
      this.pid = msg.pid;
      this.key = msg.key;
    })

    this.on('ReadyForQuery', (msg) => {
      this.busy = false;
      this.currentJob = false;
      this.transactionStatus = msg.transactionStatus;
    })
  }

  _initializeConnection() {
    var chain, i, initializer, initializers, len;
    initializers = [];
    if (!this.connectionOptions.skipInitialization) {
      if (this.connectionOptions.interruptible) {
        initializers.push(this._initializeInterrupt);
      }
      if (this.connectionOptions.role != null) {
        initializers.push(this._initializeRoles);
      }
      if (this.connectionOptions.searchPath != null) {
        initializers.push(this._initializeSearchPath);
      }
      if (this.connectionOptions.timezone != null) {
        initializers.push(this._initializeTimezone);
      }
      if (this.connectionOptions.initializer != null) {
        initializers.push(this.connectionOptions.initializer);
      }
    }
    chain = this._initializationSuccess.bind(this);
    for (i = 0, len = initializers.length; i < len; i++) {
      initializer = initializers[i];
      chain = initializer.bind(this, chain, this._initializationFailure.bind(this));
    }
    return chain();
  }

  _initializeRoles(next, fail) {
    var roles;
    roles = this.connectionOptions.role instanceof Array ? this.connectionOptions.role : [this.connectionOptions.role];
    return this._queryDirect("SET ROLE " + (roles.join(', ')), (function(_this) {
      return function(err, result) {
        if (err != null) {
          return fail(err);
        } else {
          return next();
        }
      };
    })(this));
  };

  _initializeSearchPath(next, fail) {
    var searchPath;
    searchPath = this.connectionOptions.searchPath instanceof Array ? this.connectionOptions.searchPath : [this.connectionOptions.searchPath];
    return this._queryDirect("SET SEARCH_PATH TO " + (searchPath.join(', ')), (function(_this) {
      return function(err, result) {
        if (err != null) {
          return fail(err);
        } else {
          return next();
        }
      };
    })(this));
  }

  _initializeTimezone(next, fail) {
    return this._queryDirect("SET TIMEZONE TO '" + this.connectionOptions.timezone + "'", (function(_this) {
      return function(err, result) {
        if (err != null) {
          return fail(err);
        } else {
          return next();
        }
      };
    })(this));
  }

  _initializeInterrupt(next, fail) {
    return this._queryDirect("SELECT session_id FROM v_monitor.current_session", (function(_this) {
      return function(err, result) {
        if (err != null) {
          fail(err);
        }
        _this.sessionID = result.theValue();
        return next();
      };
    })(this));
  }

  _initializationSuccess() {
    this.on('ReadyForQuery', this._processJobQueue.bind(this));
    this._processJobQueue();
    if (this.connectedCallback) {
      return this.connectedCallback(null, this);
    }
  }

  _initializationFailure(err) {
    if (this.connectedCallback) {
      return this.connectedCallback(err);
    } else {
      return this.emit('error', err);
    }
  }

  _onData(buffer) {
    var bufferedData, message, size;
    if (this.incomingData.length === 0) {
      this.incomingData = buffer;
    } else {
      bufferedData = Buffer.alloc(this.incomingData.length + buffer.length);
      this.incomingData.copy(bufferedData);
      buffer.copy(bufferedData, this.incomingData.length);
      this.incomingData = bufferedData;
    }
    while (this.incomingData.length >= 5) {
      size = this.incomingData.readUInt32BE(1);
      if (size + 1 <= this.incomingData.length) {
        message = ParseMessageFromBuffer(this.incomingData.slice(0, size + 1));
        console.debug(typeof message.constructor.name);
        if (this.debug) {
          console.debug('<=', message);
        }
        this.emit(message.constructor.name, message);
        this.incomingData = this.incomingData.slice(size + 1);
      } else {
        break;
      }
    }
    return void 0;
  };

  _onClose() {
    var error;
    this.connected = false;
    error = new ConnectionError("The connection was closed.");
    if (this.currentJob) {
      this.currentJob.onConnectionError(error);
    }
    this.currentJob = false;
    return this.emit('close');
  }

  _onTimeout() {
    var error;
    error = new ConnectionError("The connection timed out.");
    if (this.currentJob) {
      this.currentJob.onConnectionError(error);
    }
    this.currentJob = false;
    return this.emit('timeout');
  }
  
  _onError(err) {
    var error, ref;
    error = new ConnectionError((ref = err.message) != null ? ref : err.toString());
    if (this.currentJob) {
      this.currentJob.onConnectionError(error);
    }
    this.currentJob = false;
    return this.emit('error', error);
  };

  writeMessage(msg, callback) {
    if (this.debug) {
      console.log('=>', msg);
    }
    return this.connection.write(msg.toBuffer(), callback);
  };

  isInterruptible() {
    return this.sessionID != null;
  }

  _interruptConnection(cb) {
    var bareClient, bareConnectionOptions;
    if (this.sessionID != null) {
      bareConnectionOptions = {
        skipInitialization: true
      };
      bareConnectionOptions.__proto__ = this.connectionOptions;
      bareClient = new Connection(bareConnectionOptions);
      return bareClient.connect(cb);
    } else {
      return cb(new ClientStateError("Cannot interrupt connection! It's not initialized as interruptible."), null);
    }
  };

  _success(err, cb) {
    if (err != null) {
      if (cb != null) {
        cb(err);
      } else {
        this.emit('error', err);
      }
      return false;
    } else {
      return true;
    }
  };

  interruptSession(cb) {
    return this._interruptConnection((function(_this) {
      return function(err, conn) {
        if (_this._success(err, cb)) {
          return conn.query("SELECT CLOSE_SESSION('" + _this.sessionID + "')", function(err, rs) {
            conn.disconnect();
            if (_this._success(err, cb) && (cb != null)) {
              return cb(null, rs.theValue());
            }
          });
        }
      };
    })(this));
  }

  interruptStatement(cb) {
    return this._interruptConnection((function(_this) {
      return function(err, conn) {
        if (_this._success(err, cb)) {
          return conn.query("SELECT statement_id FROM v_monitor.sessions WHERE session_id = '" + _this.sessionID + "'", function(err, rs) {
            var statementID;
            if (!_this._success(err, cb)) {
              return conn.disconnect();
            } else if (rs.getLength() === 1 && (statementID = rs.theValue())) {
              return conn.query("SELECT INTERRUPT_STATEMENT('" + _this.sessionID + "', " + statementID + ")", function(err, rs) {
                conn.disconnect();
                if (_this._success(err, cb) && (cb != null)) {
                  return cb(null, rs.theValue());
                }
              });
            } else {
              conn.disconnect();
              return _this._success("Session " + _this.sessionID + " is not running a statement at the moment.", cb);
            }
          });
        }
      };
    })(this));
  }
}

export { Connection }
