assert         = require 'assert'
BackendMessage = require('../../src/backend_message')
Buffer         = require('../../src/buffer').Buffer

describe 'BackendMessage.Authentication', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00]))
    assert.ok message instanceof BackendMessage.Authentication
    assert.equal message.method, 0

  it "should read a message correctly when using MD5_PASSWORD", ->
    message = BackendMessage.fromBuffer(new Buffer([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x10]))
    assert.ok message instanceof BackendMessage.Authentication
    assert.equal message.method, 5
    assert.equal message.salt, 16

  it "should read a message correctly when using CRYPT_PASSWORD", ->
    message = BackendMessage.fromBuffer(new Buffer([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x04, 0x00, 0x10]))
    assert.ok message instanceof BackendMessage.Authentication
    assert.equal message.method, 4
    assert.equal message.salt, 16


describe 'BackendMessage.ParameterStatus', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x53, 0x00, 0x00, 0x00, 0x16, 0x61, 0x70, 0x70, 0x6c, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x5f, 0x6e, 0x61, 0x6d, 0x65, 0x00, 0x00]))
    assert.ok message instanceof BackendMessage.ParameterStatus
    assert.equal message.name,  'application_name'
    assert.equal message.value, ''


describe 'BackendMessage.BackendKeyData', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x4b, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x95, 0xb4, 0x66, 0x62, 0xa0, 0xd5]))
    assert.ok message instanceof BackendMessage.BackendKeyData
    assert.equal message.pid, 38324
    assert.equal message.key, 1717739733


describe 'BackendMessage.ReadyForQuery', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x5a, 0x00, 0x00, 0x00, 0x05, 0x49]))
    assert.ok message instanceof BackendMessage.ReadyForQuery
    assert.equal message.transactionStatus, 0x49


describe 'BackendMessage.EmptyQueryResponse', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x49, 0x00, 0x00, 0x00, 0x04]))
    assert.ok message instanceof BackendMessage.EmptyQueryResponse


describe 'BackendMessage.RowDescription', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x54, 0x00, 0x00, 0x00, 0x1b, 0x00, 0x01, 0x69, 0x64, 0x00, 0x00, 0x00, 0x75, 0x9e, 0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x00, 0x08, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]))
    assert.ok message instanceof BackendMessage.RowDescription
    assert.equal message.columns.length, 1
    assert.equal message.columns[0].tableOID, 30110
    assert.equal message.columns[0].tableFieldIndex, 1
    assert.equal message.columns[0].typeOID, 6
    assert.equal message.columns[0].type, "integer"


describe 'BackendMessage.DataRow', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x44, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x01, 0x00, 0x00, 0x00, 0x04, 0x70, 0x61, 0x69, 0x64]))
    assert.ok message instanceof BackendMessage.DataRow
    assert.equal message.values.length, 1
    assert.equal  String(message.values[0]), 'paid'


describe 'BackendMessage.CommandComplete', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([0x43, 0x00, 0x00, 0x00, 0x0b, 0x53, 0x45, 0x4c, 0x45, 0x43, 0x54, 0x00]))
    assert.ok message instanceof BackendMessage.CommandComplete
    assert.equal message.status, 'SELECT'


describe 'BackendMessage.ErrorResponse', ->
  it "ishould read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([
                    0x45, 0x00, 0x00, 0x00, 0x67, 0x53, 0x45, 0x52, 0x52, 0x4f, 0x52, 0x00, 0x43, 0x30, 0x41, 0x30, 
                    0x30, 0x30, 0x00, 0x4d, 0x63, 0x6f, 0x6d, 0x6d, 0x61, 0x6e, 0x64, 0x20, 0x4e, 0x4f, 0x54, 0x49, 
                    0x46, 0x59, 0x20, 0x69, 0x73, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x73, 0x75, 0x70, 0x70, 0x6f, 0x72, 
                    0x74, 0x65, 0x64, 0x00, 0x46, 0x76, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x2e, 0x63, 0x00, 0x4c, 
                    0x32, 0x33, 0x38, 0x30, 0x00, 0x52, 0x63, 0x68, 0x65, 0x63, 0x6b, 0x56, 0x65, 0x72, 0x74, 0x69, 
                    0x63, 0x61, 0x55, 0x74, 0x69, 0x6c, 0x69, 0x74, 0x79, 0x53, 0x74, 0x6d, 0x74, 0x53, 0x75, 0x70, 
                    0x70, 0x6f, 0x72, 0x74, 0x65, 0x64, 0x00, 0x00
                  ]))

    assert.ok message instanceof BackendMessage.ErrorResponse
    assert.equal message.information['Severity'], 'ERROR'
    assert.equal message.information['Code'], '0A000'
    assert.equal message.information['Message'], 'command NOTIFY is not supported'
    assert.equal message.information['File'], 'vertica.c'
    assert.equal message.information['Line'], '2380'
    assert.equal message.information['Routine'], 'checkVerticaUtilityStmtSupported'
    assert.equal message.message, 'command NOTIFY is not supported'


describe 'BackendMessage.NoticeResponse', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([
                    0x4e, 0x00, 0x00, 0x00, 0x67, 0x53, 0x4e, 0x4f, 0x54, 0x49, 0x43, 0x45, 0x00, 0x43, 0x30, 0x41, 
                    0x30, 0x30, 0x30, 0x00, 0x4d, 0x63, 0x6f, 0x6d, 0x6d, 0x61, 0x6e, 0x64, 0x20, 0x4e, 0x4f, 0x54, 
                    0x49, 0x46, 0x59, 0x20, 0x69, 0x73, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x73, 0x75, 0x70, 0x70, 0x6f, 
                    0x72, 0x74, 0x65, 0x64, 0x00, 0x46, 0x76, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x2e, 0x63, 0x00, 
                    0x4c, 0x32, 0x33, 0x38, 0x30, 0x00, 0x52, 0x63, 0x68, 0x65, 0x63, 0x6b, 0x56, 0x65, 0x72, 0x74, 
                    0x69, 0x63, 0x61, 0x55, 0x74, 0x69, 0x6c, 0x69, 0x74, 0x79, 0x53, 0x74, 0x6d, 0x74, 0x53, 0x75, 
                    0x70, 0x70, 0x6f, 0x72, 0x74, 0x65, 0x64, 0x00, 0x00
                  ]))

    assert.ok message instanceof BackendMessage.NoticeResponse
    assert.equal message.information['Severity'], 'NOTICE'
    assert.equal message.information['Code'], '0A000'
    assert.equal message.information['Message'], 'command NOTIFY is not supported'
    assert.equal message.information['File'], 'vertica.c'
    assert.equal message.information['Line'], '2380'
    assert.equal message.information['Routine'], 'checkVerticaUtilityStmtSupported'
    assert.equal message.message, 'command NOTIFY is not supported'


describe 'BackendMessage.CopyInResponse', ->
  it "should read a message correctly", ->
    message = BackendMessage.fromBuffer(new Buffer([71, 0, 0, 0, 7, 0, 0, 0]))
    assert.ok message instanceof BackendMessage.CopyInResponse
    assert.equal message.globalFormatType, 0
    assert.deepEqual message.fieldFormatTypes, []
