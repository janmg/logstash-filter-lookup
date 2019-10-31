# Logstash Plugin

This gem is a plugin for [Logstash](https://github.com/elastic/logstash). During filter it takes one or more fields and uses that as input to query additional information. The original purpose is to enrich IP addresses with matching subnet, netname and hostname, but it is generic so that any field can be looked up. The function is similar to the translate filter's dictionary lookup, which supports files and regex. The jdbc_streaming filter plugin is also very useful if the data resides in a database. This plugins features are web based lookups and redis caching, for fast lookups.

## Documentation

weblookup {
    fields => ['[client][ip]']
    destinations => ['net']
    url => "http://localhost/ripe.php?ip=<item>"
    use_redis => true
    redis_path => "/var/run/redis/redis-server.sock"
    normalize => true
    newroot => "[records][properties]"
    roottostrip => "[records]"
}

Where <item> will be replaced by the value of client.ip

The first three components are needed for the plugin, the others are optional. use_redis and redis_path are for caching the response, this speedsup the requists. It's also possible to hardcode values here, but I'm not using it myself yet. normalize, newroot and roottostrip probably would be better in a separte plugin, but for now weblookup can move the json objects inside the roottostrip into it's own root, by default elasticsearch uses _source as invisible root.

## Need Help?

Need help? Raise an issue on https://github.com/janmg/logstash-filter-weblookup 

