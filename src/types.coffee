
padWithZeroes = (str, length) ->
  res = "#{str}"
  res = "0#{res}" while res.length < length
  return res


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


# class VerticaTimestamp

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



exports.Date = VerticaDate
exports.Time = VerticaTime
exports.Interval = VerticaInterval
