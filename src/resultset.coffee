class Resultset

  constructor: (object) ->
    @fields  = object.fields  || []
    @rows    = object.rows    || []
    @notices = object.notices || []
    @status  = object.status


module.exports = Resultset
