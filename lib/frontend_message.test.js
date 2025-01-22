import { expect, describe, test } from 'vitest'
import { StartupMessage, CopyDataMessage, CancelRequestMessage, DescribeMessage, CloseMessage, QueryMessage, ParseMessage, BindMessage, FlushMessage, ExecuteMessage, SyncMessage, TerminateMessage, SSLRequestMessage, PasswordMessage, CopyDoneMessage, CopyFailMessage } from './frontend_message.js'
import { AuthenticationMethods } from './authentication.js'

describe("StartupMessage", () => {
  test("should hold the message's information", () => {
    const topic = new StartupMessage('username', 'database')
    expect(topic.user).toEqual('username')
    expect(topic.database).toEqual('database')
    expect(topic.options).toBeUndefined()
  })

  test("should encode the message correctly", () => {
    const topic = new StartupMessage('username', 'database')
    const reference = Buffer.from([0, 0, 0, 41, 0, 3, 0, 0, 117, 115, 101, 114, 0, 117, 115, 101, 114, 110, 97, 109, 101,
                             0, 100, 97, 116, 97, 98, 97, 115, 101, 0, 100, 97, 116, 97, 98, 97, 115, 101, 0, 0])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("CancelRequestMessage", () => {
  test("should hold the correct information", () => {
    const topic = new CancelRequestMessage(123, 456)
    expect(topic.backendPid).toEqual(123)
    expect(topic.backendKey).toEqual(456)
  })

  test("should encode the message correctly", () => {
    const topic = new CancelRequestMessage(123, 456)
    const reference = Buffer.from([0, 0, 0, 16, 4, 210, 22, 46, 0, 0, 0, 123, 0, 0, 1, 200])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("DescribeMessage", () => {
  describe("Portal", () => {
    test("should hold the correct information", () => {
      const topic = new DescribeMessage('portal', 'name')
      expect(topic.type).toEqual(80)
      expect(topic.name).toEqual('name')
    })

    test("should encode the message correctly", () => {
      const topic = new DescribeMessage('portal', 'name')
      const reference = Buffer.from([68, 0, 0, 0, 10, 80, 110, 97, 109, 101, 0])
      expect(topic.toBuffer()).toEqual(reference)
    })
  })

  describe("Prepared statement", () => {
    test("should hold the correct information", () => {
      const topic = new DescribeMessage('statement', 'name')
      expect(topic.type).toEqual(83)
      expect(topic.name).toEqual('name')
    })

    test("should encode the message correctly", () => {
      const topic = new DescribeMessage('statement', 'name')
      const reference = Buffer.from([68, 0, 0, 0, 10, 83, 110, 97, 109, 101, 0])
      expect(topic.toBuffer()).toEqual(reference)
    })
  })
})

describe("CloseMessage", () => {
  describe("Portal", () => {
    test("should hold the correct information", () => {
      const topic = new CloseMessage('portal', 'name')
      expect(topic.type).toEqual(80)
      expect(topic.name).toEqual('name')
    })

    test("should encode the message correctly", () => {
      const topic = new CloseMessage('portal', 'name')
      const reference = Buffer.from([67, 0, 0, 0, 10, 80, 110, 97, 109, 101, 0])
      expect(topic.toBuffer()).toEqual(reference)
    })
  })

  describe("Prepared statement", () => {
    test("should hold the correct information", () => {
      const topic = new CloseMessage('statement', 'name')
      expect(topic.type).toEqual(83)
      expect(topic.name).toEqual('name')
    })

    test("should encode the message correctly", () => {
      const topic = new CloseMessage('statement', 'name')
      const reference = Buffer.from([67, 0, 0, 0, 10, 83, 110, 97, 109, 101, 0])
      expect(topic.toBuffer()).toEqual(reference)
    })
  })
})

describe("QueryMessage", () => {
  test("should hold the SQL query", () => {
    const topic = new QueryMessage("SELECT * FROM table")
    expect(topic.sql).toEqual("SELECT * FROM table")
  })

  test("should encode the message correctly", () => {
    const topic = new QueryMessage("SELECT * FROM table")
    const reference = Buffer.from([81, 0, 0, 0, 24, 83, 69, 76, 69, 67, 84, 32, 42, 32, 70, 82, 79, 77, 32, 116, 97, 98, 108, 101, 0])
    expect(topic.toBuffer()).toEqual(reference)
  })
  
  test("should encode non-latin UTF-8 strings", () => {
    const topic = new QueryMessage  ("SELECT 'Привет'")
    const reference = Buffer.from([81, 0, 0, 0, 26, 83, 69, 76, 69, 67, 84, 32, 39, 208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130, 39, 0])
    expect(topic.toBuffer().toString()).toEqual(reference.toString())
  })
})

describe("ParseMessage", () => {
  test("should hold the name, query and parameter types", () => {
    const topic = new ParseMessage("test", "SELECT * FROM table", [1, 2, 3])
    expect(topic.name).toEqual("test")
    expect(topic.sql).toEqual("SELECT * FROM table")
    expect(topic.parameterTypes).toEqual([1, 2, 3])
  })

  test("should encode the message correctly", () => {
    const topic = new ParseMessage("test", "SELECT * FROM table", [1, 2, 3])
    const reference = Buffer.from([80, 0, 0, 0, 43, 116, 101, 115, 116, 0, 83, 69, 76, 69, 67, 84, 32, 42, 32, 70, 82,
                          79, 77, 32, 116, 97, 98, 108, 101, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("BindMessage", () => {
  test("should hold the portal, prepared statement name and parameter values", () => {
    const topic = new BindMessage("portal", "prep", ["hello", "world", 123])
    expect(topic.portal).toEqual("portal")
    expect(topic.preparedStatement).toEqual("prep")
    expect(topic.parameterValues).toEqual(["hello", "world", "123"])
  })

  test("should encode the message correctly", () => {
    const topic = new BindMessage("portal", "prep", ["hello", "world", 123])
    expect(topic.toBuffer()).toEqual(Buffer.from([66, 0, 0, 0, 45,
      112, 111, 114, 116, 97, 108, 0,  // "portal" (portal name)
      112, 114, 101, 112, 0,           // "prep" (prepared statement name)
      0, 0, 0, 3,                      // number of parameters (3)
      0, 0, 0, 5,                      // Length of first parameter (5)
      104, 101, 108, 108, 111,         // "hello"
      0, 0, 0, 5,                      // Length of second parameter (5)
      119, 111, 114, 108, 100,         // "world"
      0, 0, 0, 3,                      // Length of third parameter (3)
      49, 50, 51                       // "123"
    ]))
  })
})

describe("FlushMessage", () => {
  test("should encode the message correctly", () => {
    const topic = new FlushMessage()
    const reference = Buffer.from([72, 0, 0, 0, 4])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("ExecuteMessage", () => {
  test("should hold portal name and maximum number of rows", () => {
    const topic = new ExecuteMessage('portal', 100)
    expect(topic.portal).toEqual('portal')
    expect(topic.maxRows).toEqual(100)
  })

  test("should encode the message correctly", () => {
    const topic = new ExecuteMessage('portal', 100)
    const reference = Buffer.from([69, 0, 0, 0, 15, 112, 111, 114, 116, 97, 108, 0, 0, 0, 0, 100])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("SyncMessage", () => {
  test("should encode the message correctly", () => {
    const topic = new SyncMessage()
    const reference = Buffer.from([83, 0, 0, 0, 4])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("TerminateMessage", () => {
  test("should encode the message correctly", () => {
    const topic = new TerminateMessage()
    const reference = Buffer.from([88, 0, 0, 0, 4])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("SSLRequestMessage", () => {
  test("should encode the message correctly", () => {
    const topic = new SSLRequestMessage()
    const reference = Buffer.from([0, 0, 0, 8, 4, 210, 22, 47])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("PasswordMessage", () => {
  test("should encode cleartext password messages correctly", () => {
    const topic = new PasswordMessage('password')
    const reference = Buffer.from([112, 0, 0, 0, 13, 112, 97, 115, 115, 119, 111, 114, 100, 0])
    expect(topic.toBuffer()).toEqual(reference)
  })

  test("should encode MD5-hashed password messages correctly", () => {
    const topic = new PasswordMessage('password')
    topic.authMethod = AuthenticationMethods.MD5_PASSWORD
    topic.options.salt = 123
    topic.options.user = 'user'

    const reference = Buffer.from([112, 0, 0, 0, 40, 109, 100, 53, 50, 53, 52, 52, 52, 51, 56, 54, 101, 100, 53, 56, 51, 98, 53, 57, 57, 53, 48, 100, 50, 56, 98, 56, 53, 55, 52, 56, 102, 56, 49, 51, 0])
    expect(topic.toBuffer().toString()).toEqual(reference.toString())
  })
})

describe("CopyDoneMessage", () => {
  test("should format the message correctly", () => {
    const topic = new CopyDoneMessage()
    const reference = Buffer.from([99, 0, 0, 0, 4])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("CopyFailMessage", () => {
  test("should format the message correctly", () => {
    const topic = new CopyFailMessage('error')
    const reference = Buffer.from([102, 0, 0, 0, 10, 101, 114, 114, 111, 114, 0])
    expect(topic.toBuffer()).toEqual(reference)
  })
})

describe("CopyDataMessage", () => {
  test("should format the message correctly", () => {
    const topic = new CopyDataMessage(Buffer.from('123'))
    const reference = Buffer.from([100, 0, 0, 0, 7, 49, 50, 51])
    expect(topic.toBuffer()).toEqual(reference)
  })

  test("should work with both strings and buffers", () => {
    const topic = new CopyDataMessage(Buffer.from('123'))
    const other = new CopyDataMessage('123')
    expect(topic.toBuffer()).toEqual(other.toBuffer())
  })
})
