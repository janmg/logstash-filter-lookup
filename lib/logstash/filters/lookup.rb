# encoding: utf-8
require "logstash/filters/base"
require "redis"
require "json"
require "net/http"

# This  filter will replace the contents of the default
# message field with whatever you specify in the configuration.
#
# It is only intended to be used as an .
class LogStash::Filters::Lookup < LogStash::Filters::Base

  # Setting the config_name here is required. This is how you
  # configure this filter from your Logstash config.
  # [source,ruby]
  # ----------------------------------
  # filter {
  #    lookup {
  #       fields => ["ClientIP"]
  #       lookup => "http://127.0.0.1/ripe.php?ip=<item>&TOKEN=token"
  #       list => {
  #           '127.0.0.1' => '{"ip":"127.0.0.1", "subnet":"127.0.0.0/8", "netname":"localnet", "hostname":"localhost"}',
  #           '192.168.0.1' => '{"ip":"192.168.0.1", "subnet":"192.168.0.0/24", "netname":"private", "hostname":"router"}'
  #       }
  #       use_redis => false
  #    }
  # }
  # ----------------------------------
  #
  config_name "lookup"

  config :fields, :validate => :array, :required => true, :default => ["ClientIP"]
  # {"ip":"8.8.8.8","netname":"Google","subnet":"8.8.8.0\/24","hostname":"google-public-dns-a.google.com"}
  # In the query parameter has the <ip> tag will be replaced by the IP address to lookup, other parameters are optional and according to your lookup service. 
  config :lookup, :validate => :string, :required => false, :default => "http://127.0.0.1/ripe.php?ip=<item>&TOKEN=token"

  # Optional ruby hash with the key as a string and the value as a string in the form of a JSON object. These key's will not be looked up.
  config :list, :validate => :hash, :required => false

  # Optional Redis IP cache
  config :use_redis, :validate => :boolean, :required => false, :default => false
  config :redis_expiry, :validate => :number, :required => false, :default => 604800 

public
def register
    #if use_redis && !lookup.nil?
    @red = Redis.new
    #end
end # def register



def filter(event)
    fields.each do |field|
        @logger.info(event.get("["+field+"]"))
        event.set("["+field+"]", JSON.parse(find(event.get(field).to_s)))
    end
    # filter_matched should go in the last line of our successful code
    filter_matched(event)
end # def filter



def find(item)
    # Is item in list?
    res = list[item]
    unless res.nil?
        return res
    end
    # Is item in redis?
    unless @red.nil?
        res = @red.get(item)
    end
    unless res.nil?
        return res
    end
    # Lookup item in webservice and cache in redis
    #uri = URI.parse(lookup.sub('\<item\>',item))
    uri = URI.parse("http://10.0.0.5/ripe.php?ip="+item)
    res = Net::HTTP.get(uri)
    unless @red.nil?
        @red.set(item, res)
        @red.expire(item,redis_expiry)
    end
    return res
end

end # class LogStash::Filters::Lookup
