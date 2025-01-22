import EventEmitter from 'node:events'
import { QueryMessage, CopyDataMessage, CopyDoneMessage, CopyFailMessage } from './frontend_message.js'
import { Resultset } from './resultset.js'
import * as errors from './errors.js'
import { decoders } from './types.js'

class Query extends EventEmitter {
  connection
  sql
  callback

  constructor(connection, sql, callback) {
    super()

    this.connection = connection
    this.sql = sql
    this.callback = callback
    this._handlingCopyIn = false
  }

  run() {
    this.emit('start');
    this.connection.writeMessage(new QueryMessage(this.sql));

    this.connection.once('EmptyQueryResponse', this.onEmptyQueryListener = this.onEmptyQuery.bind(this));
    this.connection.on('RowDescription', this.onRowDescriptionListener = this.onRowDescription.bind(this));
    this.connection.on('DataRow', this.onDataRowListener = this.onDataRow.bind(this));
    this.connection.on('CommandComplete', this.onCommandCompleteListener = this.onCommandComplete.bind(this));
    this.connection.once('ErrorResponse', this.onErrorResponseListener = this.onErrorResponse.bind(this));
    this.connection.once('ReadyForQuery', this.onReadyForQueryListener = this.onReadyForQuery.bind(this));
    this.connection.once('CopyInResponse', this.onCopyInResponseListener = this.onCopyInResponse.bind(this));
    return this.connection.once('CopyFileResponse', this.onCopyFileResponseListener = this.onCopyFileResponse.bind(this));
  };

  onEmptyQuery(msg) {
    var err;
    err = new errors.QueryError("The query was empty!");
    if (this.callback) {
      return this.error = err;
    } else {
      return this.emit('error', err);
    }
  }

  onRowDescription(msg) {
    var column, customDecoders, decoder, err, field, i, len, ref, ref1, ref2, type;
    if (this.status && this.callback) {
      err = new errors.VerticaError("Cannot handle multi-queries with a callback!");
      this.error = err;
      return;
    }
    customDecoders = {};
    ref = this.connection.connectionOptions.decoders;
    for (type in ref) {
      decoder = ref[type];
      customDecoders[type] = decoder;
    }
    ref1 = this.decoders;
    for (type in ref1) {
      decoder = ref1[type];
      customDecoders[type] = decoder;
    }
    this.fields = [];
    ref2 = msg.columns;
    for (i = 0, len = ref2.length; i < len; i++) {
      column = ref2[i];
      field = new Field(column, customDecoders);
      this.emit('field', field);
      this.fields.push(field);
    }
    if (this.callback) {
      this.rows = [];
    }
    return this.emit('fields', this.fields);
  }

  onDataRow(msg) {
    var err, i, index, len, ref, row, value;
    try {
      row = [];
      ref = msg.values;
      for (index = i = 0, len = ref.length; i < len; index = ++i) {
        value = ref[index];
        row.push(value != null ? this.fields[index].decoder(value) : null);
      }
      if (this.callback) {
        this.rows.push(row);
      }
      return this.emit('row', row);
    } catch (error1) {
      err = error1;
      if (this.callback) {
        return this.error = err.message;
      } else {
        return this.emit('error', err.message);
      }
    }
  }

  onReadyForQuery(msg) {
    this._removeAllListeners();
    if (this.callback) {
      return process.nextTick((function(_this) {
        return function() {
          if (_this.error) {
            return _this.callback(_this.error);
          } else {
            return _this.callback(null, new Resultset({
              fields: _this.fields,
              rows: _this.rows,
              status: _this.status
            }));
          }
        };
      })(this));
    }
  }

  onCommandComplete(msg) {
    if (this.callback) {
      this.status = msg.status;
    }
    return this.emit('end', msg.status);
  }

  onErrorResponse(msg) {
    var err;
    err = new errors.QueryErrorResponse(msg);
    if (this.callback) {
      return this.error = err;
    } else {
      return this.emit('error', err);
    }
  }

  onConnectionError(msg) {
    this._removeAllListeners();
    if (this.callback) {
      return process.nextTick((function(_this) {
        return function() {
          return _this.callback(msg);
        };
      })(this));
    } else {
      return this.emit('error', msg);
    }
  }

  onCopyInResponse(msg) {
    var copyInHandler, dataHandler, err, failureHandler, successHandler;
    this._handlingCopyIn = true;
    dataHandler = (function(_this) {
      return function(data, callback) {
        return _this.copyData(data, callback);
      };
    })(this);
    successHandler = (function(_this) {
      return function(callback) {
        return _this.copyDone(callback);
      };
    })(this);
    failureHandler = (function(_this) {
      return function(err, callback) {
        return _this.copyFail(err, callback);
      };
    })(this);
    try {
      copyInHandler = this._getCopyInHandler();
      return copyInHandler(dataHandler, successHandler, failureHandler);
    } catch (error1) {
      err = error1;
      return this.copyFail(err);
    }
  }

  onCopyFileResponse(msg) {
    var error;
    error = new errors.ClientStateError("COPY FROM LOCAL is not supported.");
    return this.connection.disconnect(error);
  }

  _getCopyInHandler() {
    var existsSync, fs, stream;
    if (typeof this.copyInSource === 'function') {
      return this.copyInSource;
    } else if (typeof this.copyInSource === 'string') {
      fs = require('fs');
      existsSync = fs.existsSync || require('path').existsSync;
      if (existsSync(this.copyInSource)) {
        stream = fs.createReadStream(this.copyInSource);
        return this._getStreamCopyInHandler(stream);
      } else {
        throw new errors.ClientStateError("Could not find local file " + this.copyInSource + ".");
      }
    } else if (this.copyInSource === process.stdin) {
      process.stdin.resume();
      return this._getStreamCopyInHandler(process.stdin);
    } else if (typeof this.copyInSource === 'object' && typeof this.copyInSource.read === 'function' && typeof this.copyInSource.push === 'function') {
      return this._getStreamCopyInHandler(this.copyInSource);
    } else {
      throw new errors.ClientStateError("No copy in handler defined to handle the COPY statement.");
    }
  }

  _getStreamCopyInHandler(stream) {
    return function(transfer, success, fail) {
      stream.on('data', function(data) {
        return transfer(data);
      });
      stream.on('end', function() {
        return success();
      });
      return stream.on('error', function(err) {
        return fail(err);
      });
    };
  }

  copyData(data, callback) {
    if (this._handlingCopyIn) {
      return this.connection._writeMessage(new CopyDataMessage(data), callback);
    } else {
      throw new errors.ClientStateError("Copy in mode not active!");
    }
  }

  copyDone(callback) {
    if (this._handlingCopyIn) {
      this.connection._writeMessage(new CopyDoneMessage(), callback);
      return this._handlingCopyIn = false;
    } else {
      throw new errors.ClientStateError("Copy in mode not active!");
    }
  }

  copyFail(error, callback) {
    var message, ref;
    if (this._handlingCopyIn) {
      message = (ref = error.message) != null ? ref : error.toString();
      this.connection._writeMessage(new CopyFailMessage(message), callback);
      return this._handlingCopyIn = false; 
    } else {
      throw new errors.ClientStateError("Copy in mode not active!");
    }
  }

  _removeAllListeners() {
    this.connection.removeListener('EmptyQueryResponse', this.onEmptyQueryListener);
    this.connection.removeListener('RowDescription', this.onRowDescriptionListener);
    this.connection.removeListener('DataRow', this.onDataRowListener);
    this.connection.removeListener('CommandComplete', this.onCommandCompleteListener);
    this.connection.removeListener('ErrorResponse', this.onErrorResponseListener);
    this.connection.removeListener('ReadyForQuery', this.onReadyForQueryListener);
    this.connection.removeListener('CopyInResponse', this.onCopyInResponseListener);
    return this.connection.removeListener('CopyFileResponse', this.onCopyFileResponseListener);
  }
}
  
class Field {
  constructor(msg, customDecoders) {
    var decoder;
    this.name = msg.name;
    this.tableOID = msg.tableOID;
    this.tableFieldIndex = msg.tableFieldIndex;
    this.typeOID = msg.typeOID;
    this.type = msg.type;
    this.size = msg.size;
    this.modifier = msg.modifier;
    this.formatCode = msg.formatCode;
    if (customDecoders) {
      decoder = customDecoders[this.type] || customDecoders["default"];
    }
    this.decoder = decoder || decoders[this.formatCode][this.type] || decoders[this.formatCode]["default"];
  }
}

export { Query, Field }
