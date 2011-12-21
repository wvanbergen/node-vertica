(function() {
  var Authentication, Buffer, FrontendMessage;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  Authentication = require('./authentication');
  Buffer = require('./buffer').Buffer;
  FrontendMessage = (function() {
    function FrontendMessage() {}
    FrontendMessage.prototype.typeId = null;
    FrontendMessage.prototype.payload = function() {
      return new Buffer(0);
    };
    FrontendMessage.prototype.toBuffer = function() {
      var b, headerLength, messageBuffer, payloadBuffer, pos;
      payloadBuffer = this.payload();
      if (typeof payloadBuffer === 'string') {
        b = new Buffer(payloadBuffer.length + 1);
        b.writeZeroTerminatedString(payloadBuffer, 0);
        payloadBuffer = b;
      }
      headerLength = this.typeId != null ? 5 : 4;
      messageBuffer = new Buffer(headerLength + payloadBuffer.length);
      if (this.typeId) {
        messageBuffer.writeUInt8(this.typeId, 0);
        pos = 1;
      } else {
        pos = 0;
      }
      messageBuffer.writeUInt32(payloadBuffer.length + 4, pos);
      payloadBuffer.copy(messageBuffer, pos + 4);
      return messageBuffer;
    };
    return FrontendMessage;
  })();
  FrontendMessage.Startup = (function() {
    __extends(Startup, FrontendMessage);
    Startup.prototype.typeId = null;
    Startup.prototype.protocol = 3 << 16;
    function Startup(user, database, options) {
      this.user = user;
      this.database = database;
      this.options = options;
    }
    Startup.prototype.payload = function() {
      var pl, pos;
      pos = 0;
      pl = new Buffer(8192);
      pl.writeUInt32(this.protocol, pos);
      pos += 4;
      if (this.user) {
        pos += pl.writeZeroTerminatedString('user', pos);
        pos += pl.writeZeroTerminatedString(this.user, pos);
      }
      if (this.database) {
        pos += pl.writeZeroTerminatedString('database', pos);
        pos += pl.writeZeroTerminatedString(this.database, pos);
      }
      if (this.options) {
        pos += pl.writeZeroTerminatedString('options', pos);
        pos += pl.writeZeroTerminatedString(this.options, pos);
      }
      pl.writeUInt8(0, pos);
      pos += 1;
      return pl.slice(0, pos);
    };
    return Startup;
  })();
  FrontendMessage.SSLRequest = (function() {
    __extends(SSLRequest, FrontendMessage);
    function SSLRequest() {
      SSLRequest.__super__.constructor.apply(this, arguments);
    }
    SSLRequest.prototype.typeId = null;
    SSLRequest.prototype.sslMagicNumber = 80877103;
    SSLRequest.prototype.payload = function() {
      var pl;
      pl = new Buffer(4);
      pl.writeUInt32(this.sslMagicNumber, 0);
      return pl;
    };
    return SSLRequest;
  })();
  FrontendMessage.Password = (function() {
    __extends(Password, FrontendMessage);
    Password.prototype.typeId = 112;
    function Password(password, authMethod, options) {
      var _ref, _ref2, _ref3;
      this.password = password;
      this.authMethod = authMethod;
      this.options = options;
            if ((_ref = this.password) != null) {
        _ref;
      } else {
        this.password = '';
      };
            if ((_ref2 = this.authMethod) != null) {
        _ref2;
      } else {
        this.authMethod = Authentication.methods.CLEARTEXT_PASSWORD;
      };
            if ((_ref3 = this.options) != null) {
        _ref3;
      } else {
        this.options = {};
      };
    }
    Password.prototype.md5 = function(str) {
      var hash;
      hash = require('crypto').createHash('md5');
      hash.update(str);
      return hash.digest('hex');
    };
    Password.prototype.encodedPassword = function() {
      switch (this.authMethod) {
        case Authentication.methods.CLEARTEXT_PASSWORD:
          return this.password;
        case Authentication.methods.MD5_PASSWORD:
          return "md5" + this.md5(this.md5(this.password + this.options.user) + this.options.salt);
        default:
          throw new Error("Authentication method " + this.authMethod + " not implemented.");
      }
    };
    Password.prototype.payload = function() {
      return this.encodedPassword();
    };
    return Password;
  })();
  FrontendMessage.CancelRequest = (function() {
    __extends(CancelRequest, FrontendMessage);
    CancelRequest.prototype.cancelRequestMagicNumber = 80877102;
    function CancelRequest(backendPid, backendKey) {
      this.backendPid = backendPid;
      this.backendKey = backendKey;
    }
    CancelRequest.prototype.payload = function() {
      var b;
      b = new Buffer(12);
      b.writeUInt32(this.cancelRequestMagicNumber, 0);
      b.writeUInt32(this.backendPid, 4);
      b.writeUInt32(this.backendKey, 8);
      return b;
    };
    return CancelRequest;
  })();
  FrontendMessage.Close = (function() {
    __extends(Close, FrontendMessage);
    Close.prototype.typeId = 67;
    function Close(type, name) {
      var _ref;
      this.name = name;
            if ((_ref = this.name) != null) {
        _ref;
      } else {
        this.name = "";
      };
      this.type = (function() {
        switch (type) {
          case 'portal':
          case 'p':
          case 'P':
          case 80:
            return 80;
          case 'prepared_statement':
          case 'prepared':
          case 'statement':
          case 's':
          case 'S':
          case 83:
            return 83;
          default:
            throw new Error("" + type + " not a valid type to describe");
        }
      })();
    }
    Close.prototype.payload = function() {
      var b;
      b = new Buffer(this.name.length + 2);
      b.writeUInt8(this.type, 0);
      b.writeZeroTerminatedString(this.name, 1);
      return b;
    };
    return Close;
  })();
  FrontendMessage.Describe = (function() {
    __extends(Describe, FrontendMessage);
    Describe.prototype.typeId = 68;
    function Describe(type, name) {
      var _ref;
      this.name = name;
            if ((_ref = this.name) != null) {
        _ref;
      } else {
        this.name = "";
      };
      this.type = (function() {
        switch (type) {
          case 'portal':
          case 'P':
          case 80:
            return 80;
          case 'prepared_statement':
          case 'prepared':
          case 'statement':
          case 'S':
          case 83:
            return 83;
          default:
            throw new Error("" + type + " not a valid type to describe");
        }
      })();
    }
    Describe.prototype.payload = function() {
      var b;
      b = new Buffer(this.name.length + 2);
      b.writeUInt8(this.type, 0);
      b.writeZeroTerminatedString(this.name, 1);
      return b;
    };
    return Describe;
  })();
  FrontendMessage.Execute = (function() {
    __extends(Execute, FrontendMessage);
    Execute.prototype.typeId = 69;
    function Execute(portal, maxRows) {
      var _ref, _ref2;
      this.portal = portal;
      this.maxRows = maxRows;
            if ((_ref = this.portal) != null) {
        _ref;
      } else {
        this.portal = "";
      };
            if ((_ref2 = this.maxRows) != null) {
        _ref2;
      } else {
        this.maxRows = 0;
      };
    }
    Execute.prototype.payload = function() {
      var b, pos;
      b = new Buffer(5 + this.portal.length);
      pos = b.writeZeroTerminatedString(this.portal, 0);
      b.writeUInt32(this.maxRows, pos);
      return b;
    };
    return Execute;
  })();
  FrontendMessage.Query = (function() {
    __extends(Query, FrontendMessage);
    Query.prototype.typeId = 81;
    function Query(sql) {
      this.sql = sql;
    }
    Query.prototype.payload = function() {
      return this.sql;
    };
    return Query;
  })();
  FrontendMessage.Parse = (function() {
    __extends(Parse, FrontendMessage);
    Parse.prototype.typeId = 80;
    function Parse(name, sql, parameterTypes) {
      var _ref, _ref2;
      this.name = name;
      this.sql = sql;
      this.parameterTypes = parameterTypes;
            if ((_ref = this.name) != null) {
        _ref;
      } else {
        this.name = "";
      };
            if ((_ref2 = this.parameterTypes) != null) {
        _ref2;
      } else {
        this.parameterTypes = [];
      };
    }
    Parse.prototype.payload = function() {
      var b, paramType, pos, _i, _len, _ref;
      b = new Buffer(8192);
      pos = b.writeZeroTerminatedString(this.name, 0);
      pos += b.writeZeroTerminatedString(this.sql, pos);
      b.writeUInt16(this.parameterTypes.length, pos);
      pos += 2;
      _ref = this.parameterTypes;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        paramType = _ref[_i];
        b.writeUInt32(paramType, pos);
        pos += 4;
      }
      return b.slice(0, pos);
    };
    return Parse;
  })();
  FrontendMessage.Bind = (function() {
    __extends(Bind, FrontendMessage);
    Bind.prototype.typeId = 66;
    function Bind(portal, preparedStatement, parameterValues) {
      var parameterValue, _i, _len;
      this.portal = portal;
      this.preparedStatement = preparedStatement;
      this.parameterValues = [];
      for (_i = 0, _len = parameterValues.length; _i < _len; _i++) {
        parameterValue = parameterValues[_i];
        this.parameterValues.push(parameterValue.toString());
      }
    }
    Bind.prototype.payload = function() {
      var b, pos, value, _i, _len, _ref;
      b = new Buffer(8192);
      pos = 0;
      pos += b.writeZeroTerminatedString(this.portal, pos);
      pos += b.writeZeroTerminatedString(this.preparedStatement, pos);
      b.writeUInt16(0x00, pos);
      b.writeUInt16(this.parameterValues.length, pos + 2);
      pos += 4;
      _ref = this.parameterValues;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        value = _ref[_i];
        b.writeUInt32(value.length, pos);
        pos += 4;
        pos += b.write(value, pos);
      }
      return b.slice(0, pos);
    };
    return Bind;
  })();
  FrontendMessage.Flush = (function() {
    __extends(Flush, FrontendMessage);
    function Flush() {
      Flush.__super__.constructor.apply(this, arguments);
    }
    Flush.prototype.typeId = 72;
    return Flush;
  })();
  FrontendMessage.Sync = (function() {
    __extends(Sync, FrontendMessage);
    function Sync() {
      Sync.__super__.constructor.apply(this, arguments);
    }
    Sync.prototype.typeId = 83;
    return Sync;
  })();
  FrontendMessage.Terminate = (function() {
    __extends(Terminate, FrontendMessage);
    function Terminate() {
      Terminate.__super__.constructor.apply(this, arguments);
    }
    Terminate.prototype.typeId = 88;
    return Terminate;
  })();
  FrontendMessage.CopyData = (function() {
    __extends(CopyData, FrontendMessage);
    CopyData.prototype.typeId = 100;
    function CopyData(data) {
      this.data = data;
    }
    CopyData.prototype.payload = function() {
      return new Buffer(this.data);
    };
    return CopyData;
  })();
  FrontendMessage.CopyDone = (function() {
    __extends(CopyDone, FrontendMessage);
    function CopyDone() {
      CopyDone.__super__.constructor.apply(this, arguments);
    }
    CopyDone.prototype.typeId = 99;
    return CopyDone;
  })();
  FrontendMessage.CopyFail = (function() {
    __extends(CopyFail, FrontendMessage);
    CopyFail.prototype.typeId = 102;
    function CopyFail(error) {
      this.error = error;
    }
    CopyFail.prototype.payload = function() {
      return this.error;
    };
    return CopyFail;
  })();
  module.exports = FrontendMessage;
}).call(this);
