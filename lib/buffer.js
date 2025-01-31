import { Buffer }from 'node:buffer'

Buffer.prototype.writeZeroTerminatedString = function(str, offset, encoding) {
  var written;
  written = this.write(str, offset, encoding);
  this.writeUInt8(0, offset + written);
  return written + 1;
};

Buffer.prototype.readZeroTerminatedString = function(offset, encoding) {
  var endIndex;
  endIndex = offset;
  while (endIndex < this.length && this[endIndex] !== 0x00) {
    endIndex++;
  }
  return this.toString('ascii', offset, endIndex);
};

export { Buffer }
