padWithZeroes = (str, length) ->
  res = "#{str}"
  res = "0#{res}" while res.length < length
  return res


exports.typeOIDs =
  5:    "boolean"
  6:    "integer"
  7:    "real"
  8:    "string"
  9:    "string"
  10:   "date"
  11:   "time"
  12:   "timestamp"
  13:   "timestamp"
  14:   "interval"
  15:   "time"
  16:   "numeric"
  25:   "string"
  1043: "string"
  20:   "integer"
  21:   "integer"
  23:   "integer"
  26:   "integer"
  700:  "integer"
  701:  "integer"
  1700: "real"


################################################
# Vertica Date type
################################################

class VerticaDate
  constructor: (year, month, day) ->
    @year  = +year
    @month = +month
    @day   = +day
    
  toDate:    -> new Date(@year, @month - 1, @day)
  toString:  -> "#{padWithZeroes(@year, 4)}-#{padWithZeroes(@month, 2)}-#{padWithZeroes(@day, 2)}"
  sqlQuoted: -> "'#{@toString()}'::date"
  toJSON:    -> @toString()

  
VerticaDate.fromStringBuffer = (buffer) ->
  if matches = buffer.toString('ascii').match(/^(\d{4})-(\d{2})-(\d{2})$/)
    new VerticaDate(matches[1], matches[2], matches[3])
  else
    throw 'Invalid date format!'

VerticaDate.fromDate = (date) ->
  new VerticaDate(date.getFullYear(), date.getMonth() + 1, date.getDate())


exports.Date = VerticaDate

################################################
# Vertica Time type
################################################

class VerticaTime
  constructor: (hour, minute, second) ->
    @hour   = +hour
    @minute = +minute
    @second = +second

  toString:  -> "#{padWithZeroes(@hour, 2)}:#{padWithZeroes(@minute, 2)}:#{padWithZeroes(@second, 2)}"
  sqlQuoted: -> "'#{@toString()}'::time"
  toJSON:    -> @toString()

VerticaTime.fromStringBuffer = (buffer) ->
  if matches = buffer.toString('ascii').match(/^(\d{2}):(\d{2}):(\d{2})$/)
    new VerticaTime(matches[1], matches[2], matches[3])
  else
    throw 'Invalid time format!'

exports.Time = VerticaTime

################################################
# Vertica Timestamp type
################################################

# not implemented as a separate class as of yet
  
VerticaTimestamp =

  fromStringBuffer: (buffer) ->
    timezoneOffset = require('./vertica')
    timestampRegexp = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\.\d{1,})?(?:([\+\-])(\d{2})(?:\:(\d{2}))?)?$/
    if matches = buffer.toString('ascii').match(timestampRegexp)
      utc = Date.UTC(+matches[1], +matches[2] - 1, +matches[3], +matches[4], +matches[5], +matches[6], Math.round(+matches[7] * 1000) || 0)

      if matches[8]
        timezoneOffset = +matches[9] * 60 + (+matches[10] || 0)
        timezoneOffset = 0 - timezoneOffset if matches[8] == '-'
        utc -= timezoneOffset * 60 * 1000
      else if VerticaTimestamp.timezoneOffset
        utc -= VerticaTimestamp.timezoneOffset

      new Date(utc)

    else
      throw 'Invalid timestamp string returned'


  setTimezoneOffset: (offset) ->
    if !offset?
      VerticaTimestamp.timezoneOffset = null
    else if matches = offset.match(/^([\+\-])(\d{1,2})(?:\:(\d{2}))?$/)
      timezoneOffset = +matches[2] * 60 + (+matches[3] || 0)
      timezoneOffset = 0 - timezoneOffset if matches[1] == '-'
      VerticaTimestamp.timezoneOffset = timezoneOffset * 60 * 1000
    else
      throw "Invalid timezone offset string: #{offset}!"


exports.Timestamp = VerticaTimestamp

################################################
# Vertica Interval type
################################################

class VerticaInterval
  constructor: (days, hours, minutes, seconds) ->
    @days = +days if days?
    @hours = +hours if hours?
    @minutes = +minutes if minutes?
    @seconds = +seconds if seconds?
    
  inDays: ->
    days = 0
    days += @days if @days
    days += @hours / 24 if @hours 
    days += @minutes / (24 * 60) if @minutes
    days += @seconds / (24 * 60 / 60) if @seconds
    
  inSeconds: ->
    seconds = 0
    seconds += @days * 60 * 60 * 24 if @days
    seconds += @hours * 60 * 60 if @hours 
    seconds += @minutes * 60 if @minutes
    seconds += @seconds if @seconds
    
  inMilliseconds: ->
    @inSeconds() * 1000

  inMicroseconds: ->
    @inSeconds() * 1000000

  toJSON: ->
    days: @days, hours: @hours, minutes: @minutes, seconds: @seconds
  
  sqlQuoted: ->
    throw 'Not yet implemented'


VerticaInterval.fromStringBuffer = (buffer) ->
  if matches = buffer.toString('ascii').match(/^(\d+)?\s?(?:(\d{2}):(\d{2})(?::(\d{2}(?:\.\d+)?))?)?$/)
    new VerticaInterval(matches[1], matches[2], matches[3], matches[4])
  else
    throw 'Invalid interval format!'


exports.Interval = VerticaInterval

################################################
# value decoders
################################################

stringDecoders =
  string:    (buffer) -> buffer.toString()
  integer:   (buffer) -> +buffer
  real:      (buffer) -> parseFloat(buffer)
  numeric:   (buffer) -> parseFloat(buffer)
  boolean:   (buffer) -> buffer.toString() == 't'
  date:      (buffer) -> VerticaDate.fromStringBuffer(buffer)
  time:      (buffer) -> VerticaTime.fromStringBuffer(buffer)
  interval:  (buffer) -> VerticaInterval.fromStringBuffer(buffer)
  timestamp: (buffer) -> VerticaTimestamp.fromStringBuffer(buffer)
  default:   (buffer) -> buffer.toString()

binaryDecoders =
  default: (buffer) -> throw 'Binary decoders not yet supported!'

exports.decoders =
  0:        stringDecoders,
  1:        binaryDecoders,
  'string': stringDecoders,
  'binary': binaryDecoders

################################################
# value encoders
################################################

stringEncoders =
  string:    (value) -> value.toString()
  boolean:   (value) -> if value then 't' else 'f'
  default:   (value) -> value.toString()

binaryEncoders =
  default: (buffer) -> throw 'Binary encoders not yet supported!'

exports.encoders =
  0:        stringEncoders,
  1:        binaryEncoders,
  'string': stringEncoders,
  'binary': binaryEncoders
