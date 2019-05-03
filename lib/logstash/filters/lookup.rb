# encoding: utf-8
require 'logstash/filters/base'
require 'redis'
require 'json'
require 'net/http'
require 'connection_pool'
require 'addressable/uri'

class LogStash::Filters::Lookup < LogStash::Filters::Base

  # This is how you configure this filter from your Logstash config.
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
  config :destinations, :validate => :array, :required => false, :default => ["message"]

  # {"ip":"8.8.8.8","netname":"Google","subnet":"8.8.8.0\/24","hostname":"google-public-dns-a.google.com"}
  # In the query parameter has the <ip> tag will be replaced by the IP address to lookup, other parameters are optional and according to your lookup service. 
  config :lookup, :validate => :string, :required => false, :default => "http://localhost/ripe.php?ip=<item>&TOKEN=token"

  # Optional ruby hash with the key as a string and the value as a string in the form of a JSON object. These key's will not be looked up.
  config :list, :validate => :hash, :required => false

  # Optional Redis IP cache
  config :use_redis, :validate => :boolean, :required => false, :default => false
  config :redis_path, :validate => :string, :required => false
  config :redis_expiry, :validate => :number, :required => false, :default => 604800 
  config :normalize, :validate => :boolean, :required => false, :default => false
  HTTP_OPTIONS = {
      keep_alive_timeout: 300
  }

public
def register
    if use_redis
        unless redis_path.to_s.strip.empty?
            @red = Redis.new(path: redis_path)
        else
            @red = Redis.new()
        end
    end

    # input fields and destinations
    @is_one_destination=false
    if destinations.size == 1
        @logger.info("one destination found, it is #{destinations[0]}")
	@is_one_destination=true
    else
        if destinations.size != fields.size
            @logger.error("Configuration error, there must be an equal amount of destinations and fields, defaulting to using the field as a root for the new values. e.g. if the lookup is done on the value of [\"ClientIP\"] the destination will be [\"ClientIP\"][\"Key\"]")
            destinations=fields
        end
    end

    # http connectionpool
    @uri = Addressable::URI.parse(lookup)
    @uri.merge!(HTTP_OPTIONS)
    #@http = Net::HTTP.new(uri.host, uri.port, HTTP_OPTIONS)
    @uri.port=80 if (@uri.port.nil? && @uri.scheme=="http")
    @uri.port=443 if (@uri.port.nil? && @uri.scheme=="https")
    @connpool = ConnectionPool.new(size: 4, timeout: 180) { 
        Net::HTTP.new(@uri.host, @uri.port)
    }
end # def register

def filter(event)
    if destinations[0] == "srcdst"
        # ... do special sauce
        src = parse(event.get(fields[0]).to_s)
	dst = parse(event.get(fields[1]).to_s)
        srcdst = { :srcnet => src["netname"], :srchost => src["hostname"], :dstnet => dst["netname"], :dsthost => dst["hostname"] }
        event.set("srcdst", srcdst)
        event.get("[srcdst]").each {|k, v| event.set(k, v) }
        event.remove("[srcdst]")
	@logger.trace("processed: #{event.get(fields[0]).to_s} #{src} #{event.get(fields[1]).to_s} #{dst} #{srcdst}")
    else
        fields.each_with_index do |field, index|
            # @logger.info(event.get("["+field+"]"))
            json = parse(event.get(field).to_s)
            event.set("["+destinations[index]+"]", json)
        end
    end
    # filter_matched should go in the last line of our successful code
    filter_matched(event)
end # def filter



private
def parse(field)
    x = find(field)
    begin
        json = JSON.parse(x)
    rescue JSON::ParserError
        json = x
    end			
end

def find(item)
    res = nil
    # Is item in list? (list is an optional hash)
    unless list.nil? 
        return list[item]
    end
    # Is item in redis?
    unless @red.nil?
        res = @red.get(item)
	unless res.nil?
            return res
        end
    end
    params = @uri.query_values(Hash)
    params.each do |key, value|
        params.merge!sub(key, value, item)
    end

    @uri.query_values=(params)
    # @logger.info(@uri)
    @connpool.with do |conn|
        res = conn.request_get(@uri).read_body
        unless @red.nil?
            @red.set(item, res)
            @red.expire(item,redis_expiry)
        end
    end
    return res
end

private
def sub(key, value, item)
    return {key => item} if value=="\<item\>"
    return {key => value}
end

def normalize(event)
      event.set("net", JSON.parse(net))
      event.get("[records][properties]").each {|k, v| event.set(k, v) }
      event.remove("[records]")
      event.remove("[message]")
      return event
end

end # class LogStash::Filters::Lookup
