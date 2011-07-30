Vertica = require './src/vertica'
fs = require 'fs'

connectionOptions = JSON.parse(fs.readFileSync('./test/connection.json'))

conn = Vertica.connect connectionOptions, (err) ->
  throw err if err


conn.query "SELECT true, total_price FROM invoices ORDER BY invoice_id DESC LIMIT 1000", (args...) -> 
  console.log "Query 1 done"
  console.log args...

  conn.disconnect()



console.log 'started...'
