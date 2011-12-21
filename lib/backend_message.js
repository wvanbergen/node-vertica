(function() {
  var AuthenticationMethods, BackendMessage, messageClass, name, typeOIDs;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  AuthenticationMethods = require('./authentication').methods;
  typeOIDs = require('./types').typeOIDs;
  BackendMessage = (function() {
    BackendMessage.prototype.typeId = null;
    function BackendMessage(buffer) {
      this.read(buffer);
    }
    BackendMessage.prototype.read = function(buffer) {};
    return BackendMessage;
  })();
  BackendMessage.Authentication = (function() {
    __extends(Authentication, BackendMessage);
    function Authentication() {
      Authentication.__super__.constructor.apply(this, arguments);
    }
    Authentication.prototype.typeId = 82;
    Authentication.prototype.read = function(buffer) {
      this.method = buffer.readUInt32(0);
      if (this.method === AuthenticationMethods.MD5_PASSWORD) {
        return this.salt = stream.readUInt32(4);
      } else if (this.method === AuthenticationMethods.CRYPT_PASSWORD) {
        return this.salt = stream.readUInt16(4);
      }
    };
    return Authentication;
  })();
  BackendMessage.BackendKeyData = (function() {
    __extends(BackendKeyData, BackendMessage);
    function BackendKeyData() {
      BackendKeyData.__super__.constructor.apply(this, arguments);
    }
    BackendKeyData.prototype.typeId = 75;
    BackendKeyData.prototype.read = function(buffer) {
      this.pid = buffer.readUInt32(0);
      return this.key = buffer.readUInt32(4);
    };
    return BackendKeyData;
  })();
  BackendMessage.ParameterStatus = (function() {
    __extends(ParameterStatus, BackendMessage);
    function ParameterStatus() {
      ParameterStatus.__super__.constructor.apply(this, arguments);
    }
    ParameterStatus.prototype.typeId = 83;
    ParameterStatus.prototype.read = function(buffer) {
      this.name = buffer.readZeroTerminatedString(0);
      return this.value = buffer.readZeroTerminatedString(this.name.length + 1);
    };
    return ParameterStatus;
  })();
  BackendMessage.NotificationResponse = (function() {
    __extends(NotificationResponse, BackendMessage);
    function NotificationResponse() {
      NotificationResponse.__super__.constructor.apply(this, arguments);
    }
    NotificationResponse.prototype.typeId = 65;
    NotificationResponse.prototype.read = function(buffer) {
      this.pid = buffer.readUInt32(4);
      this.channel = buffer.readZeroTerminatedString(4);
      return this.payload = buffer.readZeroTerminatedString(this.channel.length + 5);
    };
    return NotificationResponse;
  })();
  BackendMessage.EmptyQueryResponse = (function() {
    __extends(EmptyQueryResponse, BackendMessage);
    function EmptyQueryResponse() {
      EmptyQueryResponse.__super__.constructor.apply(this, arguments);
    }
    EmptyQueryResponse.prototype.typeId = 73;
    return EmptyQueryResponse;
  })();
  BackendMessage.RowDescription = (function() {
    __extends(RowDescription, BackendMessage);
    function RowDescription() {
      RowDescription.__super__.constructor.apply(this, arguments);
    }
    RowDescription.prototype.typeId = 84;
    RowDescription.prototype.read = function(buffer) {
      var fieldDescriptor, formatCode, i, modifier, name, numberOfFields, pos, size, tableFieldIndex, tableOID, typeOID, _results;
      numberOfFields = buffer.readUInt16(0);
      pos = 2;
      this.columns = [];
      _results = [];
      for (i = 0; 0 <= numberOfFields ? i < numberOfFields : i > numberOfFields; 0 <= numberOfFields ? i++ : i--) {
        name = buffer.readZeroTerminatedString(pos);
        pos += Buffer.byteLength(name) + 1;
        tableOID = buffer.readUInt32(pos);
        pos += 4;
        tableFieldIndex = buffer.readUInt16(pos);
        pos += 2;
        typeOID = buffer.readUInt32(pos);
        pos += 4;
        size = buffer.readUInt16(pos);
        pos += 2;
        modifier = buffer.readUInt32(pos);
        pos += 4;
        formatCode = buffer.readUInt16(pos);
        pos += 2;
        fieldDescriptor = {
          name: name,
          tableOID: tableOID,
          tableFieldIndex: tableFieldIndex,
          typeOID: typeOID,
          type: typeOIDs[typeOID],
          size: size,
          modifier: modifier,
          formatCode: formatCode
        };
        _results.push(this.columns.push(fieldDescriptor));
      }
      return _results;
    };
    return RowDescription;
  })();
  BackendMessage.DataRow = (function() {
    __extends(DataRow, BackendMessage);
    function DataRow() {
      DataRow.__super__.constructor.apply(this, arguments);
    }
    DataRow.prototype.typeId = 68;
    DataRow.prototype.read = function(buffer) {
      var data, i, length, numberOfFields, pos, _results;
      numberOfFields = buffer.readUInt16(0);
      pos = 2;
      this.values = [];
      _results = [];
      for (i = 0; 0 <= numberOfFields ? i < numberOfFields : i > numberOfFields; 0 <= numberOfFields ? i++ : i--) {
        length = buffer.readUInt32(pos);
        pos += 4;
        if (length === -1) {
          data = null;
        } else {
          data = buffer.slice(pos, pos + length);
          pos += length;
        }
        _results.push(this.values.push(data));
      }
      return _results;
    };
    return DataRow;
  })();
  BackendMessage.CommandComplete = (function() {
    __extends(CommandComplete, BackendMessage);
    function CommandComplete() {
      CommandComplete.__super__.constructor.apply(this, arguments);
    }
    CommandComplete.prototype.typeId = 67;
    CommandComplete.prototype.read = function(buffer) {
      return this.status = buffer.readZeroTerminatedString(0);
    };
    return CommandComplete;
  })();
  BackendMessage.CloseComplete = (function() {
    __extends(CloseComplete, BackendMessage);
    function CloseComplete() {
      CloseComplete.__super__.constructor.apply(this, arguments);
    }
    CloseComplete.prototype.typeId = 51;
    return CloseComplete;
  })();
  BackendMessage.ParameterDescription = (function() {
    __extends(ParameterDescription, BackendMessage);
    function ParameterDescription() {
      ParameterDescription.__super__.constructor.apply(this, arguments);
    }
    ParameterDescription.prototype.typeId = 116;
    ParameterDescription.prototype.read = function(buffer) {
      var count, i;
      count = buffer.readUInt16(0);
      return this.parameterTypes = (function() {
        var _results;
        _results = [];
        for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
          _results.push(buffer.readUInt32(2 + i * 4));
        }
        return _results;
      })();
    };
    return ParameterDescription;
  })();
  BackendMessage.ParseComplete = (function() {
    __extends(ParseComplete, BackendMessage);
    function ParseComplete() {
      ParseComplete.__super__.constructor.apply(this, arguments);
    }
    ParseComplete.prototype.typeId = 49;
    return ParseComplete;
  })();
  BackendMessage.ErrorResponse = (function() {
    __extends(ErrorResponse, BackendMessage);
    function ErrorResponse() {
      ErrorResponse.__super__.constructor.apply(this, arguments);
    }
    ErrorResponse.prototype.typeId = 69;
    ErrorResponse.prototype.fieldNames = {
      83: 'Severity',
      67: 'Code',
      77: 'Message',
      68: 'Detail',
      72: 'Hint',
      80: 'Position',
      112: 'Internal position',
      113: 'Internal query',
      87: 'Where',
      70: 'File',
      76: 'Line',
      82: 'Routine'
    };
    ErrorResponse.prototype.read = function(buffer) {
      var fieldCode, pos, value;
      this.information = {};
      fieldCode = buffer.readUInt8(0);
      pos = 1;
      while (fieldCode !== 0x00) {
        value = buffer.readZeroTerminatedString(pos);
        this.information[this.fieldNames[fieldCode] || fieldCode] = value;
        pos += Buffer.byteLength(value) + 1;
        fieldCode = buffer.readUInt8(pos);
        pos += 1;
      }
      return this.message = this.information['Message'];
    };
    return ErrorResponse;
  })();
  BackendMessage.NoticeResponse = (function() {
    __extends(NoticeResponse, BackendMessage.ErrorResponse);
    function NoticeResponse() {
      NoticeResponse.__super__.constructor.apply(this, arguments);
    }
    NoticeResponse.prototype.typeId = 78;
    return NoticeResponse;
  })();
  BackendMessage.ReadyForQuery = (function() {
    __extends(ReadyForQuery, BackendMessage);
    function ReadyForQuery() {
      ReadyForQuery.__super__.constructor.apply(this, arguments);
    }
    ReadyForQuery.prototype.typeId = 90;
    ReadyForQuery.prototype.read = function(buffer) {
      return this.transactionStatus = buffer.readUInt8(0);
    };
    return ReadyForQuery;
  })();
  BackendMessage.CopyInResponse = (function() {
    __extends(CopyInResponse, BackendMessage);
    function CopyInResponse() {
      CopyInResponse.__super__.constructor.apply(this, arguments);
    }
    CopyInResponse.prototype.typeId = 71;
    CopyInResponse.prototype.read = function(buffer) {
      var i, numberOfFields, pos, _results;
      this.globalFormatType = buffer.readUInt8(0);
      this.fieldFormatTypes = [];
      numberOfFields = buffer.readUInt16(1);
      pos = 3;
      _results = [];
      for (i = 0; 0 <= numberOfFields ? i < numberOfFields : i > numberOfFields; 0 <= numberOfFields ? i++ : i--) {
        this.fieldFormatTypes.push(buffer.readUInt8(pos));
        _results.push(pos += 1);
      }
      return _results;
    };
    return CopyInResponse;
  })();
  BackendMessage.types = {};
  for (name in BackendMessage) {
    messageClass = BackendMessage[name];
    if (messageClass.prototype && (messageClass.prototype.typeId != null)) {
      messageClass.prototype.event = name;
      BackendMessage.types[messageClass.prototype.typeId] = messageClass;
    }
  }
  BackendMessage.fromBuffer = function(buffer) {
    var message, typeId;
    typeId = buffer.readUInt8(0);
    messageClass = BackendMessage.types[typeId];
    if (messageClass != null) {
      message = new messageClass(buffer.slice(5));
      return message;
    } else {
      throw new Error("Unkown message type: " + typeId);
    }
  };
  module.exports = BackendMessage;
}).call(this);
