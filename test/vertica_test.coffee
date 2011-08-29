vows    = require 'vows'
assert  = require 'assert'
Vertica = require('../src/vertica')

vow = vows.describe('Vertica')

vow.addBatch 
  'quote':
    'null': ->
      assert.equal Vertica.quote(null), 'NULL'
      assert.equal Vertica.quote(undefined), 'NULL'
  
    'numbers': ->
      assert.equal Vertica.quote(1.1), '1.1'
      assert.equal Vertica.quote(1), '1'
    
    'boolean': ->
      assert.equal Vertica.quote(true), 'TRUE'
      assert.equal Vertica.quote(false), 'FALSE'

    'strings': ->
      assert.equal Vertica.quote('hello world'), "'hello world'"
      assert.equal Vertica.quote("hello 'world'"), "'hello ''world'''"
      
    'arrays': ->
      assert.equal Vertica.quote([1, true, null, "'"]), "1, TRUE, NULL, ''''"
      
    'dates':
      'it should use the TIMESTAMP cast': ->
        d = new Date(Date.UTC(2011, 07, 29, 8, 44, 3, 123))
        assert.equal Vertica.quote(d), "TIMESTAMP('2011-08-29 08:44:03')"
    
  'quoteIdentifier': ->
    assert.equal Vertica.quoteIdentifier('hello world'), '"hello world"'
    assert.equal Vertica.quoteIdentifier('hello "world"'), '"hello ""world"""'
    

vow.export(module)
