vows    = require 'vows'
assert  = require 'assert'

Vertica = require('../src/vertica')

vow = vows.describe('Types')

vow.addBatch
  "Vertica.Date": 
    "it should construct one based on a string buffer": ->
      d = Vertica.Date.fromStringBuffer(new Buffer([50, 48, 49, 49, 45, 48, 56, 45, 50, 57]))
      assert.equal d.year,  2011
      assert.equal d.month, 8
      assert.equal d.day,   29
  
    "it should construct one based on separate values": ->
      d = new Vertica.Date(2010, 8, 30)
      assert.equal d.year,  2010
      assert.equal d.month, 8
      assert.equal d.day,   30
      
    "it should construct one based on a Javascript Date instance": ->
      d = Vertica.Date.fromDate(new Date(2010, 7, 30))
      assert.equal d.year,  2010
      assert.equal d.month, 8
      assert.equal d.day,   30
      
    "should convert into a javascript Date object": ->
      d = new Vertica.Date(2010, 8, 30)
      assert.deepEqual d.toDate(), new Date(2010, 07, 30)

    "it should convert into a string": ->
      d = new Vertica.Date(2010, 8, 30)
      assert.equal d.toString(), '2010-08-30'
    
    "it should be properly quoted for Vertica": ->
      d = new Vertica.Date(2010, 8, 30)
      assert.equal d.sqlQuoted(), "'2010-08-30'::date"

    "it should encode to JSON properly": ->
      d = new Vertica.Date(2010, 8, 30)
      assert.deepEqual d.toJSON(), '2010-08-30'


  "Vertica.Time":
    "it should construct one based on a string buffer": ->
      t = Vertica.Time.fromStringBuffer(new Buffer([48, 52, 58, 48, 53, 58, 48, 54]))
      assert.equal t.hour, 4
      assert.equal t.minute, 5
      assert.equal t.second, 6
      
    "it should encode to JSON properly": ->
      d = new Vertica.Time(4,5,6)
      assert.deepEqual d.toJSON(), '04:05:06'
      
    "it should convert to string properly": ->
      d = new Vertica.Time(4,5,6)
      assert.deepEqual "#{d}", '04:05:06'

    "it should be properly quoted for Vertica": ->
      d = new Vertica.Time(4, 5, 6)
      assert.equal d.sqlQuoted(), "'04:05:06'::time"


  "Vertica.Interval":
    "it construct one based on a string buffer with only days": ->
      i = Vertica.Interval.fromStringBuffer(new Buffer([55, 51, 48]))
      assert.equal i.days, 730
      assert.ok !i.hours?
      assert.ok !i.minutes?
      assert.ok !i.seconds?

    "it construct one based on a string buffer with only hours": ->
      i = Vertica.Interval.fromStringBuffer(new Buffer([48, 50, 58, 48, 48]))
      assert.ok !i.days?
      assert.equal i.hours, 2
      assert.equal i.minutes, 0
      assert.ok !i.seconds?

    "it construct one based on a string buffer with only minutes": ->
      i = Vertica.Interval.fromStringBuffer(new Buffer([48, 48, 58, 48, 50]))
      assert.ok !i.days?
      assert.equal i.hours, 0
      assert.equal i.minutes, 2
      assert.ok !i.seconds?

    "it construct one based on a string buffer with only seconds": ->
      i = Vertica.Interval.fromStringBuffer(new Buffer([48, 48, 58, 48, 48, 58, 48, 50]))
      assert.ok !i.days?
      assert.equal i.hours, 0
      assert.equal i.minutes, 0
      assert.equal i.seconds, 2

    "it construct one based on a string buffer with only seconds and microseconds": ->
      i = Vertica.Interval.fromStringBuffer(new Buffer([48, 48, 58, 48, 48, 58, 48, 48, 46, 48, 48, 48, 48, 48, 50]))
      assert.ok !i.days?
      assert.equal i.hours, 0
      assert.equal i.minutes, 0
      assert.equal i.seconds, 0.000002

    "it construct one based on a string buffer with both days and microseconds": ->
      i = Vertica.Interval.fromStringBuffer(new Buffer([50, 32, 48, 48, 58, 48, 48, 58, 48, 48, 46, 48, 48, 48, 48, 48, 50]))
      assert.equal i.days, 2
      assert.equal i.hours, 0
      assert.equal i.minutes, 0
      assert.equal i.seconds, 0.000002
      
    "it should calculate the duration correctly": ->
      i = new Vertica.Interval(2, 3, 4, 5.006007)
      assert.equal i.inDays(), 2.336361402777778
      assert.equal i.inSeconds(), 183845.006007
      assert.equal i.inMilliseconds(), 183845006.007
      assert.equal i.inMicroseconds(), 183845006007

    "it should encode to JSON properly": ->
      i = new Vertica.Interval(2, 3, 4, 5.006007)
      assert.deepEqual i.toJSON(), days: 2, hours: 3, minutes: 4, seconds: 5.006007

vow.export(module)
