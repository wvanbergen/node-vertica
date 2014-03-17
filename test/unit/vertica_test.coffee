assert  = require 'assert'
Vertica = require('../../src/vertica')

describe 'Vertica', ->
  
  describe '.quote()', ->
    it "should quote `null` properly", ->
      assert.equal Vertica.quote(null), 'NULL'
      assert.equal Vertica.quote(undefined), 'NULL'

    it "should quote numbers properly", ->
      assert.equal Vertica.quote(1.1), '1.1'
      assert.equal Vertica.quote(1), '1'

    it "should quote booleans properly", ->
      assert.equal Vertica.quote(true), 'TRUE'
      assert.equal Vertica.quote(false), 'FALSE'


    it "should quote strings properly", ->
      assert.equal Vertica.quote('hello world'), "'hello world'"
      assert.equal Vertica.quote("hello 'world'"), "'hello ''world'''"

    it "should quote lists of values properly", ->
      assert.equal Vertica.quote([1, true, null, "'"]), "1, TRUE, NULL, ''''"

    it "should quote dates properly", ->
      d = new Date(Date.UTC(2011, 7, 29, 8, 44, 3, 123))
      assert.equal Vertica.quote(d), "'2011-08-29 08:44:03'::timestamp"


  describe '.quoteIdentifier()', ->
    it "should quote indentifiers properly", ->
      assert.equal Vertica.quoteIdentifier('hello world'), '"hello world"'
      assert.equal Vertica.quoteIdentifier('hello "world"'), '"hello ""world"""'
