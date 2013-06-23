Benchtable = require 'benchtable'
Types      = require '../src/types'

decoders = Types.decoders.string
suite = new Benchtable()

suite.addFunction 'string', (v) ->
  decoders.string(v)

suite.addFunction 'integer', (v) ->
  decoders.integer(v)

suite.addFunction 'real', (v) ->
  decoders.numeric(v)

suite.addFunction 'numeric', (v) ->
  decoders.numeric(v)

suite.addInput '123', new Buffer('123')
suite.addInput '3.14159265359', new Buffer('3.14159265359')

suite.on 'cycle', (event) ->
  console.log event.target.toString()

suite.on 'complete', ->
  console.log this.table.toString()

suite.run()
