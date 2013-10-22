require( 'coffee-script' );
var options = ['-f', process.env.FEED_URL, '-k', process.env.CLIENT_TOKEN, '-s', process.env.CLIENT_TOKEN_SECRET, '-t', process.env.TOKEN, '-S', process.env.TOKEN_SECRET, '-c', process.env.CRON_STRING ];
process.argv = [].concat( process.argv.slice(0,2), options);

require( './status' );
require( './repost' );
