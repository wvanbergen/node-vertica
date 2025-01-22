import { createHash } from "node:crypto"  
import { AuthenticationMethods } from './authentication.js'
import { Buffer } from './buffer.js'

class FrontendMessage {
  typeId = null

  payload() {
    return Buffer.alloc(0);
  }

  toBuffer() {
    var b, bLength, headerLength, messageBuffer, payloadBuffer, pos;
    payloadBuffer = this.payload();
    if (typeof payloadBuffer === 'string') {
      bLength = Buffer.byteLength(payloadBuffer);
      b = Buffer.alloc(bLength + 1);
      b.writeZeroTerminatedString(payloadBuffer, 0);
      payloadBuffer = b;
    }
    headerLength = this.typeId != null ? 5 : 4;
    messageBuffer = Buffer.alloc(headerLength + payloadBuffer.length);
    if (this.typeId) {
      messageBuffer.writeUInt8(this.typeId, 0);
      pos = 1;
    } else {
      pos = 0;
    }
    messageBuffer.writeUInt32BE(payloadBuffer.length + 4, pos);
    payloadBuffer.copy(messageBuffer, pos + 4);
    return messageBuffer;
  }
}

class StartupMessage extends FrontendMessage {
  typeId = null;
  protocol = 3 << 16;

  constructor(user, database, options) {
    super()
    this.user = user;
    this.database = database;
    this.options = options;
  }

  payload() {
    var pl, pos;
    pos = 0;
    pl = Buffer.alloc(8192);
    pl.writeUInt32BE(this.protocol, pos);
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
  }
}
  
class SSLRequestMessage extends FrontendMessage {
  typeId = null;
  sslMagicNumber = 80877103;

  payload() {
    var pl;
    pl = Buffer.alloc(4);
    pl.writeUInt32BE(this.sslMagicNumber, 0);
    return pl;
  }
}

class PasswordMessage extends FrontendMessage {
  typeId = 112;

  constructor(password, authMethod, options) {
    super()

    this.password = password;
    this.authMethod = authMethod;
    this.options = options;
    if (this.password == null) {
      this.password = '';
    }
    if (this.authMethod == null) {
      this.authMethod = AuthenticationMethods.CLEARTEXT_PASSWORD;
    }
    if (this.options == null) {
      this.options = {};
    }    
  }

  md5() {
    var i, len, value, values;
    // values = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    const hash = createHash('md5');
    for (const value of arguments) {
      hash.update(value);
    }
    return hash.digest('hex');
  }

  encodedPassword() {
    var salt;
    switch (this.authMethod) {
      case AuthenticationMethods.CLEARTEXT_PASSWORD:
        return this.password;
      case AuthenticationMethods.MD5_PASSWORD:
        salt = Buffer.alloc(4);
        salt.writeUInt32BE(this.options.salt, 0);
        return "md5" + this.md5(this.md5(this.password, this.options.user), salt);
      default:
        throw new Error("Authentication method " + this.authMethod + " not implemented.");
    }
  }

  payload() {
    return this.encodedPassword();
  }
}

class CancelRequestMessage extends FrontendMessage {
  cancelRequestMagicNumber = 80877102;
  backendPid
  backendKey

  constructor(backendPid, backendKey) {
    super()
    
    this.backendPid = backendPid;
    this.backendKey = backendKey;
  }

  payload() {
    var b;
    b = Buffer.alloc(12);
    b.writeUInt32BE(this.cancelRequestMagicNumber, 0);
    b.writeUInt32BE(this.backendPid, 4);
    b.writeUInt32BE(this.backendKey, 8);
    return b;
  }
}

class CloseMessage extends FrontendMessage {
  typeId = 67
  name
  type

  constructor(type, name) {
    super()

    this.name = name;
    if (this.name == null) {
      this.name = "";
    }

    switch (type) {
      case 'portal':
      case 'p':
      case 'P':
      case 80:
        this.type = 80;
        break

      case 'prepared_statement':
      case 'prepared':
      case 'statement':
      case 's':
      case 'S':
      case 83:
        this.type = 83;
        break

      default:
        throw new Error(type + " not a valid type to describe");
    }
  }

  payload() {
    const b = Buffer.alloc(this.name.length + 2)
    b.writeUInt8(this.type, 0)
    b.writeZeroTerminatedString(this.name, 1)
    return b
  }
}

class DescribeMessage extends FrontendMessage {
  typeId = 68;
  name
  type

  constructor(type, name) {
    super()

    this.name = name
    if (this.name == null) {
      this.name = "";
    }
    switch (type) {
      case 'portal':
      case 'P':
      case 80:
        this.type =  80;
        break

      case 'prepared_statement':
      case 'prepared':
      case 'statement':
      case 'S':
      case 83:
        this.type =  83;
        break
        
      default:
        throw new Error(type + " not a valid type to describe");
    }
  }

  payload() {
    const b = Buffer.alloc(this.name.length + 2);
    b.writeUInt8(this.type, 0);
    b.writeZeroTerminatedString(this.name, 1);
    return b;
  }
}

class ExecuteMessage extends FrontendMessage {
  typeId = 69;

  portal
  maxRows

  constructor(portal, maxRows) {
    super()

    this.portal = portal;
    this.maxRows = maxRows;
    if (this.portal == null) {
      this.portal = "";
    }
    if (this.maxRows == null) {
      this.maxRows = 0;
    }
  }

  payload() {
    const b = Buffer.alloc(5 + this.portal.length);
    const pos = b.writeZeroTerminatedString(this.portal, 0);
    b.writeUInt32BE(this.maxRows, pos);
    return b;
  }
}

class QueryMessage extends FrontendMessage {
  typeId = 81;
  sql

  constructor(sql) {  
    super()

    this.sql = sql;
  }

  payload() {
    return this.sql;
  }
}

class ParseMessage extends FrontendMessage {
  typeId = 80;
  name
  sql
  parameterTypes

  constructor(name, sql, parameterTypes) {
    super()

    this.name = name;
    this.sql = sql;
    this.parameterTypes = parameterTypes;
    if (this.name == null) {
      this.name = "";
    }
    if (this.parameterTypes == null) {
      this.parameterTypes = [];
    }
  }

  payload() {
    const b = Buffer.alloc(8192);
    let pos = b.writeZeroTerminatedString(this.name, 0);
    pos += b.writeZeroTerminatedString(this.sql, pos);
    b.writeUInt16BE(this.parameterTypes.length, pos);
    pos += 2
    for (let i = 0; i < this.parameterTypes.length; i++) {
      const paramType = this.parameterTypes[i];
      b.writeUInt32BE(paramType, pos);
      pos += 4;
    }
    return b.slice(0, pos);
  }
}

class BindMessage extends FrontendMessage {
  typeId = 66;

  portal
  preparedStatement
  parameterValues

  constructor(portal, preparedStatement, parameterValues) {
    super()

    this.portal = portal;
    this.preparedStatement = preparedStatement;
    this.parameterValues = [];
    for (let i = 0; i < parameterValues.length; i++) {
      const parameterValue = parameterValues[i];
      this.parameterValues.push(parameterValue.toString());
    }
  }

  payload() {
    const b = Buffer.alloc(8192);
    let pos = 0;

    pos += b.writeZeroTerminatedString(this.portal, pos)
    pos += b.writeZeroTerminatedString(this.preparedStatement, pos)
    
    b.writeUInt16BE(0x00, pos)
    b.writeUInt16BE(this.parameterValues.length, pos + 2)
    pos += 4

    for (let i = 0; i < this.parameterValues.length; i++) {
      const value = this.parameterValues[i]
      b.writeUInt32BE(value.length, pos)
      pos += 4
      pos += b.write(value, pos)
    }
    return b.slice(0, pos)
  }
}

class FlushMessage extends FrontendMessage {
  typeId = 72
}

class SyncMessage extends FrontendMessage {
  typeId = 83
}

class TerminateMessage extends FrontendMessage {
  typeId = 88
}

class CopyDataMessage extends FrontendMessage {
  typeId = 100
  data

  constructor(data) {
    super()
    this.data = data
  }

  payload() {
    return new Buffer(this.data);
  }
}

class CopyDoneMessage extends FrontendMessage {
  typeId = 99
}

class CopyFailMessage extends FrontendMessage {
  typeId = 102
  error

  constructor(error) {
    super()
    this.error = error;
  }

  payload() {
    return this.error;
  }
}

export { StartupMessage, SSLRequestMessage, PasswordMessage, CancelRequestMessage, CloseMessage, DescribeMessage, ExecuteMessage, QueryMessage, ParseMessage, BindMessage, FlushMessage, SyncMessage, TerminateMessage, CopyDataMessage, CopyDoneMessage, CopyFailMessage }
