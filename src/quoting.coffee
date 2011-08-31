exports.escape = (val) ->
  val.toString().replace(/'/g, "''")

exports.quote = (val) ->
  if !val?
    'NULL'
  else if typeof val.sqlQuoted == 'function'
    val.sqlQuoted()
  else if val == true
    'TRUE'
  else if val == false
    'FALSE'
  else if typeof val == 'number'
    val.toString()
  else if typeof val == 'string'
    "'#{exports.escape(val)}'"
  else if val instanceof Array
    (exports.quote(v) for v in val).join(', ')
  else if val instanceof Date
    "TIMESTAMP('#{val.toISOString().replace(/T/, ' ').replace(/\.\d+Z$/, '')}')"
  else 
    "'#{exports.escape(val)}'"

exports.quoteIdentifier = (val) ->
  '"' + val.toString().replace(/"/g, '""') + '"'
