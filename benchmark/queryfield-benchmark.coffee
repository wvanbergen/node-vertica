Benchtable = require 'benchtable'
Query      = require '../src/query'

suite = new Benchtable()

msg =
  formatCode : 'string'
  type       : 'integer'

suite.addFunction 'constructor', (options) ->
  new Query.Field msg, options

suite.addInput 'vanilla', null
suite.addInput 'custom decoder', {
  integer: (v) -> +v
}
suite.addInput 'custom default decoder', {
  default: (v) -> v.toString()
}

suite.on 'cycle', (event) ->
  console.log event.target.toString()

suite.on 'complete', ->
  console.log this.table.toString()

suite.run()
