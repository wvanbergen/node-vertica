stringDecoders =
  string:   (value) -> value.toString()
  integer:  (value) -> +value
  float:    (value) -> parseFloat(value)
  decimal:  (value) -> parseFloat(value)
  bool:     (value) -> value.toString() == 't'

  timestamp: (value) ->
    timestampRegexp = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\.\d{1,})?(?:([\+\-])(\d{2})(?:\:(\d{2}))?)?$/

    if matches = value.toString('ascii').match(timestampRegexp)
      utc = Date.UTC(+matches[1], +matches[2] - 1, +matches[3], +matches[4], +matches[5], +matches[6], Math.round(+matches[7] * 1000))

      if matches[8]
        timezoneOffset = +matches[9] * 60 + (+matches[10] || 0)
        timezoneOffset = 0 - timezoneOffset if matches[8] == '-'
        utc -= timezoneOffset * 60 * 1000

      new Date(utc)

    else
      throw 'Invalid date string returned'


  date: (value) ->
    year   = +value.slice(0, 4)
    month  = +value.slice(5, 7) - 1
    day    = +value.slice(8, 10)
    new Date(Date.UTC(year, month, day))

  default: (value) -> value.toString()


binaryDecoders = 
  default: (value) -> 
    throw 'Binary decoders not yet supported!'


module.exports = 0: stringDecoders, 1: binaryDecoders, 'string': stringDecoders, 'binary': binaryDecoders
