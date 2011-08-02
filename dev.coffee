Vertica = require './src/vertica'
fs = require 'fs'

connectionOptions = JSON.parse(fs.readFileSync('./test/connection.json'))

conn = Vertica.connect connectionOptions, (err) ->
  throw err if err


query = """
   SELECT NULL, DATE 'now', TIME 'now', TIMESTAMP 'now', INTERVAL '9 DAY'
"""

conn.query query, (args...) -> 
  console.log "Query 1 done"
  console.log args...

  conn.disconnect()



console.log 'started...'
