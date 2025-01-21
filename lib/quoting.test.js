import { expect, describe, test } from 'vitest'

import { quote, quoteIdentifier } from './quoting.js'

describe("quote", () => {
    test("should quote null properly", () => {
        expect(quote(null)).toEqual('NULL')
    })

    test("should quote numbers properly", () => {
        expect(quote(1.1)).toEqual('1.1')
        expect(quote(1)).toEqual('1')
    })

    test("should quote booleans properly", () => {
        expect(quote(true)).toEqual('TRUE')
        expect(quote(false)).toEqual('FALSE')
    })


    test("should quote strings properly", () => {
        expect(quote('hello world')).toEqual("'hello world'")
        expect(quote("hello 'world'")).toEqual("'hello ''world'''")
    })

    test("should quote lists of values properly", () => {
        expect(quote([1, true, null, "'"])).toEqual("1, TRUE, NULL, ''''")
    })

    test("should quote dates properly", () => {
        const d = new Date(Date.UTC(2011, 7, 29, 8, 44, 3, 123))
        expect(quote(d)).toEqual("'2011-08-29 08:44:03'::timestamp")
    }) 
})

describe("quoteIdentifier", () => {
    test("should quote identifiers properly", () => {
        expect(quoteIdentifier('hello world')).toEqual('"hello world"')
        expect(quoteIdentifier('hello "world"')).toEqual('"hello ""world"""')
    })
})