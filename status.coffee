options = process.argv.slice(2)

http = require 'http'
server = http.createServer (req, res) ->
  res.write "date: #{(new Date).toString()}\n"
  options.forEach (option) ->
    res.write "#{option}\n"
  res.end '^_^\n'
server.listen process.env.VCAP_APP_PORT || 8000
