(function() {
  var EventEmitter, FrontendMessage, Query, Resultset, decoders;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  EventEmitter = require('events').EventEmitter;

  FrontendMessage = require('./frontend_message');

  decoders = require('./types').decoders;

  Resultset = require('./resultset');

  Query = (function() {

    __extends(Query, EventEmitter);

    function Query(connection, sql, callback) {
      this.connection = connection;
      this.sql = sql;
      this.callback = callback;
      this._handlingCopyIn = false;
    }

    Query.prototype.run = function() {
      this.emit('start');
      this.connection._writeMessage(new FrontendMessage.Query(this.sql));
      this.connection.once('EmptyQueryResponse', this.onEmptyQueryListener = this.onEmptyQuery.bind(this));
      this.connection.on('RowDescription', this.onRowDescriptionListener = this.onRowDescription.bind(this));
      this.connection.on('DataRow', this.onDataRowListener = this.onDataRow.bind(this));
      this.connection.on('CommandComplete', this.onCommandCompleteListener = this.onCommandComplete.bind(this));
      this.connection.once('ErrorResponse', this.onErrorResponseListener = this.onErrorResponse.bind(this));
      this.connection.once('ReadyForQuery', this.onReadyForQueryListener = this.onReadyForQuery.bind(this));
      return this.connection.once('CopyInResponse', this.onCopyInResponseListener = this.onCopyInResponse.bind(this));
    };

    Query.prototype.onEmptyQuery = function() {
      if (!this.callback) this.emit('error', "The query was empty!");
      if (this.callback) return this.callback("The query was empty!");
    };

    Query.prototype.onRowDescription = function(msg) {
      var column, field, _i, _len, _ref;
      if ((this.callback != null) && (this.status != null)) {
        throw "Cannot handle multi-queries with a callback!";
      }
      this.fields = [];
      _ref = msg.columns;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        column = _ref[_i];
        field = new Query.Field(column);
        this.emit('field', field);
        this.fields.push(field);
      }
      if (this.callback) this.rows = [];
      return this.emit('fields', this.fields);
    };

    Query.prototype.onDataRow = function(msg) {
      var index, row, value, _len, _ref;
      row = [];
      _ref = msg.values;
      for (index = 0, _len = _ref.length; index < _len; index++) {
        value = _ref[index];
        row.push(value != null ? this.fields[index].decoder(value) : null);
      }
      if (this.callback) this.rows.push(row);
      return this.emit('row', row);
    };

    Query.prototype.onReadyForQuery = function(msg) {
      if (this.callback) {
        this.callback(null, new Resultset({
          fields: this.fields,
          rows: this.rows,
          status: this.status
        }));
      }
      return this._removeAllListeners();
    };

    Query.prototype.onCommandComplete = function(msg) {
      if (this.callback) this.status = msg.status;
      return this.emit('end', msg.status);
    };

    Query.prototype.onErrorResponse = function(msg) {
      this._removeAllListeners();
      if (!this.callback) this.emit('error', msg.message);
      if (this.callback) return this.callback(msg);
    };

    Query.prototype.onCopyInResponse = function(msg) {
      var copyInHandler, dataHandler, failureHandler, successHandler;
      var _this = this;
      this._handlingCopyIn = true;
      dataHandler = function(data) {
        return _this.copyData(data);
      };
      successHandler = function() {
        return _this.copyDone();
      };
      failureHandler = function(err) {
        return _this.copyFail(err);
      };
      copyInHandler = this._getCopyInHandler();
      return copyInHandler(dataHandler, successHandler, failureHandler);
    };

    Query.prototype._getCopyInHandler = function() {
      var stream;
      if (typeof this.copyInSource === 'function') {
        return this.copyInSource;
      } else if (typeof this.copyInSource === 'string') {
        if (require('path').existsSync(this.copyInSource)) {
          stream = require('fs').createReadStream(this.copyInSource);
          return this._getStreamCopyInHandler(stream);
        } else {
          return this.copyFail("Could not find local file " + this.dataSource + ".");
        }
      } else if (this.copyInSource === process.stdin) {
        process.stdin.resume();
        return this._getStreamCopyInHandler(process.stdin);
      } else {
        throw "No copy in handler defined to handle the COPY statement.";
      }
    };

    Query.prototype._getStreamCopyInHandler = function(stream) {
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
    };

    Query.prototype.copyData = function(data) {
      if (this._handlingCopyIn) {
        return this.connection._writeMessage(new FrontendMessage.CopyData(data));
      } else {
        throw "Copy in mode not active!";
      }
    };

    Query.prototype.copyDone = function() {
      if (this._handlingCopyIn) {
        this.connection._writeMessage(new FrontendMessage.CopyDone());
        return this._handlingCopyIn = false;
      } else {
        throw "Copy in mode not active!";
      }
    };

    Query.prototype.copyFail = function(error) {
      if (this._handlingCopyIn) {
        this.connection._writeMessage(new FrontendMessage.CopyFail(error.toString()));
        return this._handlingCopyIn = false;
      } else {
        throw "Copy in mode not active!";
      }
    };

    Query.prototype._removeAllListeners = function() {
      this.connection.removeListener('EmptyQueryResponse', this.onEmptyQueryListener);
      this.connection.removeListener('RowDescription', this.onRowDescriptionListener);
      this.connection.removeListener('DataRow', this.onDataRowListener);
      this.connection.removeListener('CommandComplete', this.onCommandCompleteListener);
      this.connection.removeListener('ErrorResponse', this.onErrorResponseListener);
      this.connection.removeListener('ReadyForQuery', this.onReadyForQueryListener);
      return this.connection.removeListener('CopyInResponse', this.onCopyInResponseListener);
    };

    return Query;

  })();

  Query.Field = (function() {

    function Field(msg) {
      this.name = msg.name;
      this.tableOID = msg.tableOID;
      this.tableFieldIndex = msg.tableFieldIndex;
      this.typeOID = msg.typeOID;
      this.type = msg.type;
      this.size = msg.size;
      this.modifier = msg.modifier;
      this.formatCode = msg.formatCode;
      this.decoder = decoders[this.formatCode][this.type] || decoders[this.formatCode]["default"];
    }

    return Field;

  })();

  module.exports = Query;

}).call(this);
