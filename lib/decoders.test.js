import { expect, describe, test } from 'vitest'
import { decoders, Date as VerticaDate, Time as VerticaTime, Timestamp } from './types.js'

describe("binary decoders", () => {
    test("should decode strings properly", () => {
        const data = new Buffer([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100])
        expect(decoders.binary.string(data)).toEqual('hello world')
    })

    test("should throw an exception by default", () => {
        expect(() => decoders.binary.default(new Buffer)).toThrow()
    })
})

describe("string decoders", () => {
    test("should decode type timestamp with timezone", () => {
        // Negative timezone
        const negativeTimezone = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 49, 55, 58, 51, 57, 58, 52, 53, 46, 54, 54, 53, 48, 53, 49, 45, 48, 50, 58, 51, 48])
        expect(decoders.string.timestamp(negativeTimezone)).toEqual(new Date(Date.UTC(2011, 7, 29, 20, 9, 45, 665)))

        // Positive timezone
        const positiveTimezone = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 50, 50, 58, 49, 50, 58, 52, 48, 46, 48, 51, 50, 50, 43, 48, 50])
        expect(decoders.string.timestamp(positiveTimezone)).toEqual(new Date(Date.UTC(2011, 7, 29, 20, 12, 40, 32)))

        // UTC = no offset
        const utc = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 50, 48, 58, 49, 52, 58, 52, 53, 46, 54, 55, 49, 52, 52, 55, 43, 48, 48])
        expect(decoders.string.timestamp(utc)).toEqual(new Date(Date.UTC(2011, 7, 29, 20, 14, 45, 671)))
    })

    test("should decode type timestamp without timezone", () => {
        // Use UTC by default
        const data = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 49, 55, 58, 51, 52, 58, 52, 48, 46, 53, 52, 54, 54, 48, 53])
        expect(decoders.string.timestamp(data)).toEqual(new Date(Date.UTC(2011, 7, 29, 17, 34, 40, 547)))

        // Set global timezone offset to +2
        Timestamp.setTimezoneOffset("+2")
        expect(decoders.string.timestamp(data)).toEqual(new Date(Date.UTC(2011, 7, 29, 15, 34, 40, 547)))

        Timestamp.setTimezoneOffset(null)
    })

    test("should decode type date", () => {
        const data = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57])
        expect(decoders.string.date(data)).toEqual(new VerticaDate(2011, 8, 29))
    })

    test("should decode type time", () => {
        const data = new Buffer([48, 52, 58, 48, 53, 58, 48, 54])
        expect(decoders.string.time(data)).toEqual(new VerticaTime(4,5,6))
    })

    test("should decode type string", () => {
        const data = Buffer.from([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100])
        expect(decoders.string.string(data)).toEqual('hello world')
    })

    test("should decode type integer", () => {
        const data = Buffer.from([49])
        expect(decoders.string.integer(data)).toEqual(1)
    })

    test("should decode type real", () => {
        const data = Buffer.from([49, 46, 51, 51])
        expect(decoders.string.real(data)).toEqual(1.33)
    })

    test("should decode type numeric", () => {
        const data = Buffer.from([49, 48, 46, 53])
        expect(decoders.string.real(data)).toEqual(10.5)
    })

    test("should decode type boolean", () => {
        expect(decoders.string.boolean(new Buffer([116]))).toEqual(true)
        expect(decoders.string.boolean(new Buffer([102]))).toEqual(false)
    })
})