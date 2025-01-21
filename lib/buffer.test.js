import { expect, test } from 'vitest'
import { Buffer } from './buffer.js'

test('writeZeroTerminatedString', () => {
  const topic = Buffer.from([1,1,1,1,1])
  topic.writeZeroTerminatedString('test', 0)
  expect(topic).toEqual(Buffer.from([116, 101, 115, 116, 0]))
})

test('readZeroTerminatedString from start of buffer', () => {
  const topic = Buffer.from([80,0,80,80,0])
  expect(topic.readZeroTerminatedString(0)).toEqual('P')
})

test('readZeroTerminatedString from middle of buffer', () => {
  const topic = Buffer.from([80,0,80,80,0])
  expect(topic.readZeroTerminatedString(2)).toEqual('PP')
})
