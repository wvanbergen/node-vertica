import { describe, expect, test } from 'vitest'
import { Date as VerticaDate, Time as VerticaTime, Interval as VerticaInterval } from './types.js'

describe("Vertica.Date", () => {
    test("fromStringBuffer should construct one based on a string buffer", () => {
        const d = VerticaDate.fromStringBuffer(Buffer.from([50, 48, 49, 49, 45, 48, 56, 45, 50, 57]))
        expect(d.year).toEqual(2011)
        expect(d.month).toEqual(8)
        expect(d.day).toEqual(29)
    })

    test("constructor should construct one based on separate values", () => {
        const d = new VerticaDate(2010, 8, 30)
        expect(d.year).toEqual(2010)
        expect(d.month).toEqual(8)
        expect(d.day).toEqual(30)
    })
        
    test("fromDate should construct one based on a Javascript Date instance", () => {
        const d = VerticaDate.fromDate(new Date(2010, 7, 30))
        expect(d.year).toEqual(2010)
        expect(d.month).toEqual(8)
        expect(d.day).toEqual(30)
    })

    test("toDate should convert into a javascript Date object", () => {
        const d = new VerticaDate(2010, 8, 30)
        expect(d.toDate()).toEqual(new Date(2010, 7, 30))
    })

    test("toString should convert into a string", () => {
        const d = new VerticaDate(2010, 8, 30)
        expect(d.toString()).toEqual('2010-08-30')
    })
    
    test("sqlQuoted should be properly quoted for Vertica", () => {
        const d = new VerticaDate(2010, 8, 30)
        expect(d.sqlQuoted()).toEqual("'2010-08-30'::date")
    })

    test("toJSON should encode to JSON properly", () => {
        const d = new VerticaDate(2010, 8, 30)
        expect(d.toJSON()).toEqual('2010-08-30')
    })
})

describe("Vertica.Time", () => {
    test("fromStringBuffer should construct one based on a string buffer", () => {
        const t = VerticaTime.fromStringBuffer(Buffer.from([48, 52, 58, 48, 53, 58, 48, 54]))
        expect(t.hour).toEqual(4)
        expect(t.minute).toEqual(5)
        expect(t.second).toEqual(6)
    })

    test("toJSON should encode to JSON properly", () => {
        const t = new VerticaTime(4,5,6)
        expect(t.toJSON()).toEqual('04:05:06')
    })
    
    test("toString should convert to string properly", () => {
        const t = new VerticaTime(4,5,6)
        expect(t.toString()).toEqual('04:05:06')
    })

    test("sqlQuoted should be properly quoted for Vertica", () => {
        const t = new VerticaTime(4, 5, 6)
        expect(t.sqlQuoted()).toEqual("'04:05:06'::time")
    })
})

describe("Vertica.Interval", () => {
    test("fromStringBuffer should construct one based on a string buffer with only days", () => {
        const i = VerticaInterval.fromStringBuffer(Buffer.from([55, 51, 48]))
        expect(i.days).toEqual(730)
        expect(i.hours).toBeUndefined()
        expect(i.minutes).toBeUndefined()
        expect(i.seconds).toBeUndefined()
    })

    test("fromStringBuffer should construct one based on a string buffer with only hours", () => {
        const i = VerticaInterval.fromStringBuffer(Buffer.from([48, 50, 58, 48, 48]))
        expect(i.days).toBeUndefined()
        expect(i.hours).toEqual(2)
        expect(i.minutes).toEqual(0)
        expect(i.seconds).toBeUndefined()
    })

    test("fromStringBuffer should construct one based on a string buffer with only minutes", () => {
        const i = VerticaInterval.fromStringBuffer(Buffer.from([48, 48, 58, 48, 50]))
        expect(i.days).toBeUndefined()
        expect(i.hours).toEqual(0)
        expect(i.minutes).toEqual(2)
        expect(i.seconds).toBeUndefined()
    })

    test("fromStringBuffer should construct one based on a string buffer with only seconds", () => {
        const i = VerticaInterval.fromStringBuffer(Buffer.from([48, 48, 58, 48, 48, 58, 48, 50]))
        expect(i.days).toBeUndefined()
        expect(i.hours).toEqual(0)
        expect(i.minutes).toEqual(0)
        expect(i.seconds).toEqual(2)
    })

    test("fromStringBuffer should construct one based on a string buffer with only seconds and microseconds", () => {
        const i = VerticaInterval.fromStringBuffer(Buffer.from([48, 48, 58, 48, 48, 58, 48, 48, 46, 48, 48, 48, 48, 48, 50]))
        expect(i.days).toBeUndefined()
        expect(i.hours).toEqual(0)
        expect(i.minutes).toEqual(0)
        expect(i.seconds).toEqual(0.000002)
    })

    test("fromStringBuffer should construct one based on a string buffer with both days and microseconds", () => {
        const i = VerticaInterval.fromStringBuffer(Buffer.from([50, 32, 48, 48, 58, 48, 48, 58, 48, 48, 46, 48, 48, 48, 48, 48, 50]))
        expect(i.days).toEqual(2)
        expect(i.hours).toEqual(0)
        expect(i.minutes).toEqual(0)
        expect(i.seconds).toEqual(0.000002)
    })
    
    test("should calculate the duration correctly", () => {
        const i = new VerticaInterval(2, 3, 4, 5.006007)
        expect(i.inDays()).toEqual(2.336361402777778)
        expect(i.inSeconds()).toEqual(183845.006007)
        expect(i.inMilliseconds()).toEqual(183845006.007)
        expect(i.inMicroseconds()).toEqual(183845006007)
    })

    test("should encode to JSON properly", () => {
        const i = new VerticaInterval(2, 3, 4, 5.006007)
        expect(i.toJSON()).toEqual({ days: 2, hours: 3, minutes: 4, seconds: 5.006007 })
    })
})