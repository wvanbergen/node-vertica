import { expect, describe, test } from 'vitest'
import { Buffer } from './buffer.js'
import BackendMessage from './backend_message.js'

describe("BackendMessage.Authentication", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00]))
    expect(message).toBeInstanceOf(BackendMessage.Authentication)
    expect(message.method).toBe(0)
  })

  test("should read a message correctly when using MD5_PASSWORD", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x10]))
    expect(message).toBeInstanceOf(BackendMessage)
    expect(message.method).toBe(5)
    expect(message.salt).toBe(16)
  })

  test("should read a message correctly when using CRYPT_PASSWORD", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x52, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x04, 0x00, 0x10]))
    expect(message).toBeInstanceOf(BackendMessage.Authentication)
    expect(message.method).toBe(4)
    expect(message.salt).toBe(16)
  })
})

describe("BackendMessage.ParameterStatus", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x53, 0x00, 0x00, 0x00, 0x16, 0x61, 0x70, 0x70, 0x6c, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x5f, 0x6e, 0x61, 0x6d, 0x65, 0x00, 0x00]))
    expect(message).toBeInstanceOf(BackendMessage.ParameterStatus)
    expect(message.name).toBe('application_name')
    expect(message.value).toBe('')
  })
})

describe("BackendMessage.BackendKeyData", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x4b, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x95, 0xb4, 0x66, 0x62, 0xa0, 0xd5]))
    expect(message).toBeInstanceOf(BackendMessage.BackendKeyData)
    expect(message.pid).toBe(38324)
    expect(message.key).toBe(1717739733)
  })
})

describe("BackendMessage.ReadyForQuery", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x5a, 0x00, 0x00, 0x00, 0x05, 0x49]))
    expect(message).toBeInstanceOf(BackendMessage.ReadyForQuery)
    expect(message.transactionStatus).toBe(0x49)
  })
})

describe("BackendMessage.EmptyQueryResponse", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x49, 0x00, 0x00, 0x00, 0x04]))
    expect(message).toBeInstanceOf(BackendMessage.EmptyQueryResponse)
  })
})

describe("BackendMessage.RowDescription", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x54, 0x00, 0x00, 0x00, 0x1b, 0x00, 0x01, 0x69, 0x64, 0x00, 0x00, 0x00, 0x75, 0x9e, 0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x00, 0x08, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]))
    expect(message).toBeInstanceOf(BackendMessage.RowDescription)
    expect(message.columns.length).toBe(1)
    expect(message.columns[0].tableOID).toBe(30110)
    expect(message.columns[0].tableFieldIndex).toBe(1)
    expect(message.columns[0].typeOID).toBe(6)
    expect(message.columns[0].type).toBe("integer")
  })
})

describe("BackendMessage.DataRow", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x44, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x01, 0x00, 0x00, 0x00, 0x04, 0x70, 0x61, 0x69, 0x64]))
    expect(message).toBeInstanceOf(BackendMessage.DataRow)
    expect(message.values.length).toBe(1)
    expect(String(message.values[0])).toBe('paid')
  })
})

describe("BackendMessage.CommandComplete", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([0x43, 0x00, 0x00, 0x00, 0x0b, 0x53, 0x45, 0x4c, 0x45, 0x43, 0x54, 0x00]))
    expect(message).toBeInstanceOf(BackendMessage.CommandComplete)
    expect(message.status).toBe('SELECT')
  })
})

describe("BackendMessage.ErrorResponse", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([
      0x45, 0x00, 0x00, 0x00, 0x67, 0x53, 0x45, 0x52, 0x52, 0x4f, 0x52, 0x00, 0x43, 0x30, 0x41, 0x30,
      0x30, 0x30, 0x00, 0x4d, 0x63, 0x6f, 0x6d, 0x6d, 0x61, 0x6e, 0x64, 0x20, 0x4e, 0x4f, 0x54, 0x49,
      0x46, 0x59, 0x20, 0x69, 0x73, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x73, 0x75, 0x70, 0x70, 0x6f, 0x72,
      0x74, 0x65, 0x64, 0x00, 0x46, 0x76, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x2e, 0x63, 0x00, 0x4c,
      0x32, 0x33, 0x38, 0x30, 0x00, 0x52, 0x63, 0x68, 0x65, 0x63, 0x6b, 0x56, 0x65, 0x72, 0x74, 0x69,
      0x63, 0x61, 0x55, 0x74, 0x69, 0x6c, 0x69, 0x74, 0x79, 0x53, 0x74, 0x6d, 0x74, 0x53, 0x75, 0x70,
      0x70, 0x6f, 0x72, 0x74, 0x65, 0x64, 0x00, 0x00
    ]))

    expect(message).toBeInstanceOf(BackendMessage.ErrorResponse)
    expect(message.information['Severity']).toBe('ERROR')
    expect(message.information['Code']).toBe('0A000')
    expect(message.information['Message']).toBe('command NOTIFY is not supported')
    expect(message.information['File']).toBe('vertica.c')
    expect(message.information['Line']).toBe('2380')
    expect(message.information['Routine']).toBe('checkVerticaUtilityStmtSupported')
    expect(message.message).toBe('command NOTIFY is not supported')
  })
})

describe("BackendMessage.NoticeResponse", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([
      0x4e, 0x00, 0x00, 0x00, 0x67, 0x53, 0x4e, 0x4f, 0x54, 0x49, 0x43, 0x45, 0x00, 0x43, 0x30, 0x41,
      0x30, 0x30, 0x30, 0x00, 0x4d, 0x63, 0x6f, 0x6d, 0x6d, 0x61, 0x6e, 0x64, 0x20, 0x4e, 0x4f, 0x54,
      0x49, 0x46, 0x59, 0x20, 0x69, 0x73, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x73, 0x75, 0x70, 0x70, 0x6f,
      0x72, 0x74, 0x65, 0x64, 0x00, 0x46, 0x76, 0x65, 0x72, 0x74, 0x69, 0x63, 0x61, 0x2e, 0x63, 0x00,
      0x4c, 0x32, 0x33, 0x38, 0x30, 0x00, 0x52, 0x63, 0x68, 0x65, 0x63, 0x6b, 0x56, 0x65, 0x72, 0x74,
      0x69, 0x63, 0x61, 0x55, 0x74, 0x69, 0x6c, 0x69, 0x74, 0x79, 0x53, 0x74, 0x6d, 0x74, 0x53, 0x75,
      0x70, 0x70, 0x6f, 0x72, 0x74, 0x65, 0x64, 0x00, 0x00
    ]))

    expect(message).toBeInstanceOf(BackendMessage.NoticeResponse)
    expect(message.information['Severity']).toBe('NOTICE')
    expect(message.information['Code']).toBe('0A000')
    expect(message.information['Message']).toBe('command NOTIFY is not supported')
    expect(message.information['File']).toBe('vertica.c')
    expect(message.information['Line']).toBe('2380')
    expect(message.information['Routine']).toBe('checkVerticaUtilityStmtSupported')
    expect(message.message).toBe('command NOTIFY is not supported')
  })
})

describe("BackendMessage.CopyInResponse", () => {
  test("should read a message correctly", () => {
    const message = BackendMessage.fromBuffer(Buffer.from([71, 0, 0, 0, 7, 0, 0, 0]))
    expect(message).toBeInstanceOf(BackendMessage.CopyInResponse)
    expect(message.globalFormatType).toBe(0)
    expect(message.fieldFormatTypes).toEqual([])
  })
})
