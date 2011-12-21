(function() {
  var Buffer, _base, _base10, _base2, _base3, _base4, _base5, _base6, _base7, _base8, _base9, _ref, _ref10, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;

  Buffer = require('buffer').Buffer;

  if ((_ref = (_base = Buffer.prototype).writeUInt8) == null) {
    _base.writeUInt8 = function(number, offset) {
      this[offset] = number & 0xff;
    };
  }

  if ((_ref2 = (_base2 = Buffer.prototype).writeUInt16) == null) {
    _base2.writeUInt16 = function(number, offset, endian) {
      return this._writeUInt(2, number, offset, endian);
    };
  }

  if ((_ref3 = (_base3 = Buffer.prototype).writeUInt32) == null) {
    _base3.writeUInt32 = function(number, offset, endian) {
      return this._writeUInt(4, number, offset, endian);
    };
  }

  if ((_ref4 = (_base4 = Buffer.prototype)._writeUInt) == null) {
    _base4._writeUInt = function(bytes, number, offset, endian) {
      var currentOffset, encodingPositions, index, _i, _j, _len, _ref5, _ref6, _results, _results2;
      encodingPositions = endian === 'little' ? (function() {
        _results = [];
        for (var _i = offset, _ref5 = offset + bytes - 1; offset <= _ref5 ? _i <= _ref5 : _i >= _ref5; offset <= _ref5 ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this) : (function() {
        _results2 = [];
        for (var _j = _ref6 = offset + bytes - 1; _ref6 <= offset ? _j <= offset : _j >= offset; _ref6 <= offset ? _j++ : _j--){ _results2.push(_j); }
        return _results2;
      }).apply(this);
      for (index = 0, _len = encodingPositions.length; index < _len; index++) {
        currentOffset = encodingPositions[index];
        this[currentOffset] = (number >> (8 * index)) & 0xff;
      }
    };
  }

  if ((_ref5 = (_base5 = Buffer.prototype).writeZeroTerminatedString) == null) {
    _base5.writeZeroTerminatedString = function(str, offset, encoding) {
      var written;
      written = this.write(str, offset, null, encoding);
      this.writeUInt8(0, offset + written);
      return written + 1;
    };
  }

  if ((_ref6 = (_base6 = Buffer.prototype).readUInt8) == null) {
    _base6.readUInt8 = function(offset) {
      return this[offset];
    };
  }

  if ((_ref7 = (_base7 = Buffer.prototype).readUInt16) == null) {
    _base7.readUInt16 = function(offset, endian) {
      return this._readUInt(2, offset, endian);
    };
  }

  if ((_ref8 = (_base8 = Buffer.prototype).readUInt32) == null) {
    _base8.readUInt32 = function(offset, endian) {
      return this._readUInt(4, offset, endian);
    };
  }

  if ((_ref9 = (_base9 = Buffer.prototype)._readUInt) == null) {
    _base9._readUInt = function(bytes, offset, endian) {
      var currentOffset, encodingPositions, index, number, _i, _j, _len, _ref10, _ref11, _results, _results2;
      encodingPositions = endian === 'little' ? (function() {
        _results = [];
        for (var _i = offset, _ref10 = offset + bytes - 1; offset <= _ref10 ? _i <= _ref10 : _i >= _ref10; offset <= _ref10 ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this) : (function() {
        _results2 = [];
        for (var _j = _ref11 = offset + bytes - 1; _ref11 <= offset ? _j <= offset : _j >= offset; _ref11 <= offset ? _j++ : _j--){ _results2.push(_j); }
        return _results2;
      }).apply(this);
      number = 0;
      for (index = 0, _len = encodingPositions.length; index < _len; index++) {
        currentOffset = encodingPositions[index];
        number = (this[currentOffset] << (index * 8)) | number;
      }
      return number;
    };
  }

  if ((_ref10 = (_base10 = Buffer.prototype).readZeroTerminatedString) == null) {
    _base10.readZeroTerminatedString = function(offset, encoding) {
      var endIndex;
      endIndex = offset;
      while (endIndex < this.length && this[endIndex] !== 0x00) {
        endIndex++;
      }
      return this.toString('ascii', offset, endIndex);
    };
  }

  exports.Buffer = Buffer;

}).call(this);
