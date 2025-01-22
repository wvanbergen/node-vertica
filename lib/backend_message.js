import { AuthenticationMethods } from './authentication.js'
import { typeOIDs } from './types.js';

class Authentication {
  read(buffer) {
    this.method = buffer.readUInt32BE(0);
    if (this.method === AuthenticationMethods.MD5_PASSWORD) {
      this.salt = buffer.readUInt32BE(4);
    } else if (this.method === AuthenticationMethods.CRYPT_PASSWORD) {
      this.salt = buffer.readUInt16BE(4);
    }
  }
}

class BackendKeyData {
  pid
  key

  read(buffer) {
    this.pid = buffer.readUInt32BE(0);
    this.key = buffer.readUInt32BE(4);
  }
}

class ParameterStatus {
  name
  value

  read(buffer) {
    this.name = buffer.readZeroTerminatedString(0);
    this.value = buffer.readZeroTerminatedString(this.name.length + 1);
  }
}

class NotificationResponse {
  pid
  channel
  payload

  read(buffer) {
    this.pid = buffer.readUInt32BE(4);
    this.channel = buffer.readZeroTerminatedString(4);
    this.payload = buffer.readZeroTerminatedString(this.channel.length + 5);
  }
}

class EmptyQueryResponse {
  payload 

  read(buffer) {
    this.payload = buffer.readZeroTerminatedString(4);
  }
}

class RowDescription {
  columns = []

  read(buffer) {
    const numberOfFields = buffer.readUInt16BE(0);
    let pos = 2;
    for (let i = 0; i < numberOfFields; i++) {
      const name = buffer.readZeroTerminatedString(pos);
      pos += Buffer.byteLength(name) + 1;
      const tableOID = buffer.readUInt32BE(pos);
      pos += 4;
      const tableFieldIndex = buffer.readUInt16BE(pos);
      pos += 2;
      const typeOID = buffer.readUInt32BE(pos);
      pos += 4;
      const size = buffer.readUInt16BE(pos);
      pos += 2;
      const modifier = buffer.readUInt32BE(pos);
      pos += 4;
      const formatCode = buffer.readUInt16BE(pos);
      pos += 2;
      const fieldDescriptor = {
        name: name,
        tableOID: tableOID,
        tableFieldIndex: tableFieldIndex,
        typeOID: typeOID,
        type: typeOIDs[typeOID],
        size: size,
        modifier: modifier,
        formatCode: formatCode
      };
      this.columns.push(fieldDescriptor);
    }
  }
}

class DataRow {
  values = []

  read(buffer) {
    const numberOfFields = buffer.readUInt16BE(0);
    let pos = 2;
    for (let i = 0; i < numberOfFields; i++) {
      const length = buffer.readUInt32BE(pos);
      pos += 4

      let data = null
      if (length !== 4294967295) {
        data = buffer.slice(pos, pos + length);
        pos += length;
      }

      this.values.push(data);
    }
  }
}

class CommandComplete {
  status 

  read(buffer) {
    this.status = buffer.readZeroTerminatedString(0)
  }
}

class CloseComplete {
  status

  read(buffer) {
    this.status = buffer.readZeroTerminatedString(0)
  }
}

class ParameterDescription {
  parameterTypes = []

  read(buffer) {
    var i;
    const count = buffer.readUInt16BE(0);
    this.parameterTypes = (function() {
      var j, ref, results;
      results = [];
      for (i = j = 0, ref = count; 0 <= ref ? j < ref : j > ref; i = 0 <= ref ? ++j : --j) {
        results.push(buffer.readUInt32BE(2 + i * 4));
      }
      return results;
    })();
  }
}

class ParseComplete {
  status

  read(buffer) {
    this.status = buffer.readZeroTerminatedString(0);
  }
}

class ErrorResponse {
  static fieldNames = {
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
  }

  message
  information = {}

  read(buffer) {
    let fieldCode = buffer.readUInt8(0);
    let pos = 1;
    while (fieldCode !== 0x00) {
      let value = buffer.readZeroTerminatedString(pos);
      this.information[ErrorResponse.fieldNames[fieldCode] || fieldCode] = value;
      pos += Buffer.byteLength(value) + 1;
      fieldCode = buffer.readUInt8(pos);
      pos += 1;
    }
    this.message = this.information['Message'];
  }
}

class NoticeResponse extends ErrorResponse {
  static typeId = 78
}

class ReadyForQuery {
  transactionStatus

  read(buffer) {
    this.transactionStatus = buffer.readUInt8(0)
  }
}

class CopyFileResponse {
  files = []
  last

  read(buffer) {
    const numberOfFiles = buffer.readUInt16BE(0);
    let pos = 2;
    for (let i = 0; i < numberOfFiles; i++) {
      let filename = buffer.readZeroTerminatedString(pos);
      this.files.push(filename);
      pos += filename.length + 1;
    }
    this.last = buffer.readUInt16BE(pos);
  }
}

class CopyInResponse {
  globalFormatType
  fieldFormatTypes = []

  read(buffer) {
    this.globalFormatType = buffer.readUInt8(0);
    const numberOfFields = buffer.readUInt16BE(1);
    let pos = 3;
    for (let i = 0; i < numberOfFields; i++) {
      this.fieldFormatTypes.push(buffer.readUInt8(pos));
      pos += 1;
    }
  }
}

export const MessageTypes = {
  82: Authentication,
  75: BackendKeyData,
  83: ParameterStatus,
  65: NotificationResponse,
  73: EmptyQueryResponse,
  84: RowDescription,
  68: DataRow,
  67: CommandComplete,
  51: CloseComplete,
  116: ParameterDescription,
  49: ParseComplete,
  69: ErrorResponse,
  78: NoticeResponse,
  90: ReadyForQuery,
  70: CopyFileResponse,
  71: CopyInResponse,
}

const ParseMessageFromBuffer = function(buffer) {
  const typeId = buffer.readUInt8(0)
  const messageClass = MessageTypes[typeId]
  if (messageClass != null) {
    const msg = new messageClass()
    msg.read(buffer.slice(5))
    return msg
  } else {
    throw new Error("Unknown message type: " + typeId)
  }
}

export { ParseMessageFromBuffer }
export { Authentication, BackendKeyData, ParameterStatus, NotificationResponse, 
          EmptyQueryResponse, RowDescription, DataRow, CommandComplete, CloseComplete, 
          ParameterDescription, ParseComplete, ErrorResponse, NoticeResponse, ReadyForQuery, 
          CopyFileResponse, CopyInResponse }