vows    = require 'vows'
assert  = require 'assert'
ValueDecoders = require('../src/value_decoders')

vow = vows.describe('Value Decoders')

vow.addBatch
  'string decoders':
  
    'timestamp with timezone': ->
      # Negative timezone
      data = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 49, 55, 58, 51, 57, 58, 52, 53, 46, 54, 54, 53, 48, 53, 49, 45, 48, 50, 58, 51, 48])
      assert.deepEqual ValueDecoders.string.timestamp(data), new Date(Date.UTC(2011, 7, 29, 20, 09, 45, 665))

      # Positive timezone
      data = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 50, 50, 58, 49, 50, 58, 52, 48, 46, 48, 51, 50, 50, 43, 48, 50])
      assert.deepEqual ValueDecoders.string.timestamp(data), new Date(Date.UTC(2011, 7, 29, 20, 12, 40, 32))

      # UTC = no offset
      data = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 50, 48, 58, 49, 52, 58, 52, 53, 46, 54, 55, 49, 52, 52, 55, 43, 48, 48])
      assert.deepEqual ValueDecoders.string.timestamp(data), new Date(Date.UTC(2011, 7, 29, 20, 14, 45, 671))


    'timestamp without timezone': ->
      data = new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57, 32, 49, 55, 58, 51, 52, 58, 52, 48, 46, 53, 52, 54, 54, 48, 53])
      assert.deepEqual ValueDecoders.string.timestamp(data), new Date(Date.UTC(2011, 7, 29, 17, 34, 40, 547))


vow.export(module)
      