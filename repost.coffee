request = require 'request'
xml2js = require 'xml2js'
fs = require 'fs'
_ = require 'underscore'
async = require 'async'
qs = require 'querystring'
cli = require 'commander'
util = require 'util'

cli
  .option('-l, --last-post [path]', 'File to read and store last tweeted post', 'last_post')
  .option('-b, --blacklist [path]', 'File with an array of blacklisted urls', 'blacklist')
  .option('-f, --feed-url <url>', 'Feed URL (ATOM)')
  .option('-p, --proxy [url]', 'Proxy URL')
  .option('-k, --consumer-key <key>', 'Your App\'s Twitter Consumer Key')
  .option('-s, --consumer-secret <secret>', 'Your App\'s Twitter Consumer Secret')
  .option('-t, --token <token>', 'Your Twitter Token')
  .option('-S, --token-secret <secret>', 'Your Twitter Token Secret')
  .option('-K, --keep-posting [milliseconds]', 'Keep the command posting each XXX milliseconds')
  .parse(process.argv)

last_post_file = cli.lastPost
blacklist_file = cli.blacklist
feed_url = cli.feedUrl
proxy = cli.proxy
consumer_key = cli.consumerKey
consumer_secret = cli.consumerSecret
token = cli.token
token_secret = cli.tokenSecret
keep_posting = cli.keepPosting

return console.log 'Missing required params' if not feed_url or not consumer_key or not consumer_secret or not token or not token_secret

parser = new xml2js.Parser
  explicitArray: false
  mergeAttrs: true

retry_times = 0
retry_in = 5000

main = ->
  async.waterfall [fetch_feed, parse_feed, read_last_post, post_tweet, save_last_post], (err)->
    if err
      console.log err
      if retry_times < 3
        console.log "will retry in #{retry_in} milliseconds"
        setTimeout ->
          retry_times += 1
          retry_in *= 2
          main()
        , retry_in
      else
        console.log "too many retries"
    else
      if keep_posting
        retry_times = 0
        retry_in = 5000
        console.log "repeating in #{keep_posting} milliseconds"
        setTimeout main, keep_posting

fetch_feed = (callback) ->
  console.log 'fetching feed'
  request
    proxy: proxy
    url: feed_url
  , (err, response, body) ->
    callback err, body

parse_feed = (feed, callback) ->
  console.log 'parsing feed'
  parser.parseString feed, (err, obj) ->
    # extract urls and titles as a dictionary
    console.log 'extracting urls'
    entries = obj?.feed?.entry.reduce (dict, obj) ->
      dict[ obj?.link?.href ] = obj.title._
      return dict
    , {}
    callback err, entries

read_last_post = (entries, callback) ->
  console.log 'reading configuration files'
  async.parallel
    last_post: (callback) ->
      fs.readFile last_post_file, (err, data) ->
        callback null, data?.toString()
    blacklist: (callback) ->
      fs.readFile blacklist_file, (err, data) ->
        callback null, data?.toString()
  , (err, data) ->
    # destruct the results into individual variables
    {last_post, blacklist} = data
    # if there is no blacklist, use an empty array
    try
      blacklist = JSON.parse blacklist
    catch err
      blacklist = []
    # get independent arrays of urls
    urls = _.keys entries
    console.log 'removing blacklisted urls'
    # remove blacklisted urls
    urls = _.difference urls, blacklist
    callback null, entries, urls, last_post

post_tweet = (entries, urls, last_post, callback) ->
  index = urls.indexOf last_post
  index = if index - 1 < 0 then urls.length - 1 else index - 1

  status = "#{entries[urls[index]]} #{urls[index]}"
  console.log "posting tweet: #{status}"
  request
    proxy: proxy
    method: 'post'
    url: 'https://api.twitter.com/1.1/statuses/update.json'
    oauth:
      consumer_key: consumer_key
      consumer_secret: consumer_secret
      token: token
      token_secret: token_secret
    form:
      status: status
  , (err, response, body) ->
    console.log "twitter response: #{util.inspect body}"
    callback err, urls[index]

save_last_post = (posted_url, callback) ->
  console.log 'saving last posted url'
  fs.writeFile last_post_file, posted_url, (err) ->
    callback()

main()
