class Resultset

  constructor: (object) ->
    @fields  = object.fields  || []
    @rows    = object.rows    || []
    @notices = object.notices || []
    @status  = object.status

  theValue: ->
    @rows[0][0]

  getLength: ->
    @rows.length


module.exports = Resultset
