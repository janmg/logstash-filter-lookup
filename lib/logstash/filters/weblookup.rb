# encoding: utf-8
require 'logstash/filters/base'
require 'redis'
require 'json'
require 'net/http'
require 'connection_pool'
require 'addressable/uri'

class LogStash::Filters::Webookup < LogStash::Filters::Base

  # This is how you configure this filter from your Logstash config.
  # [source,ruby]
  # ----------------------------------
  # filter {
  #    weblookup {
  #       fields => ["ClientIP"]
  #       url => "http://127.0.0.1/ripe.php?ip=<item>&TOKEN=token"
  #       list => {
  #           '127.0.0.1' => '{"ip":"127.0.0.1", "subnet":"127.0.0.0/8", "netname":"localnet", "hostname":"localhost"}',
  #           '192.168.0.1' => '{"ip":"192.168.0.1", "subnet":"192.168.0.0/24", "netname":"private", "hostname":"router"}'
  #       }
  #       use_redis => false
  #    }
  # }
  # ----------------------------------
  #
  config_name "weblookup"

  config :fields, :validate => :array, :required => true, :default => ["ClientIP"]
  # {"ip":"8.8.8.8","netname":"Google","subnet":"8.8.8.0\/24","hostname":"google-public-dns-a.google.com"}
  # In the query parameter has the <ip> tag will be replaced by the IP address to lookup, other parameters are optional and according to your lookup service. 
  config :destinations, :validate => :array, :required => false, :default => ["message"]

  # {"ip":"8.8.8.8","netname":"Google","subnet":"8.8.8.0\/24","hostname":"google-public-dns-a.google.com"}
  # In the query parameter has the <ip> tag will be replaced by the IP address to lookup, other parameters are optional and according to your lookup service. 
  config :url, :validate => :string, :required => false, :default => "http://localhost/ripe.php?ip=<item>&TOKEN=token"

  # Optional ruby hash with the key as a string and the value as a string in the form of a JSON object. These key's will not be looked up.
  config :list, :validate => :hash, :required => false

  # Optional Redis IP cache
  config :use_redis, :validate => :boolean, :required => false, :default => false
  config :redis_path, :validate => :string, :required => false
  config :redis_expiry, :validate => :number, :required => false, :default => 604800 

  # Optional simplify the message by moving a field to be the new root of the message
  config :normalize, :validate => :boolean, :required => false, :default => false
  config :newroot, :validate => :string, :required => false
  config :roottostrip, :validate => :string, :required => false

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
        # add case destination is empty to put the result in under the same field 
    end

    # http connectionpool
    @uri = Addressable::URI.parse(url)
    @uri.merge!(HTTP_OPTIONS)
    #@http = Net::HTTP.new(uri.host, uri.port, HTTP_OPTIONS)
    @uri.port=80 if (@uri.port.nil? && @uri.scheme=="http")
    @uri.port=443 if (@uri.port.nil? && @uri.scheme=="https")
    # find the key where the value is <item>, otherwise just use the value
    @params = @uri.query_values(Hash)
    @params.each do |key, value|
        if value == "\<item\>" 
            @ip=key
	    @params.delete(key)
	    logger.info("the ip key in the uri is #{@ip}")
        end
    end
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
            begin
             json = parse(event.get(field).to_s)
             event.set("["+destinations[index]+"]", json)
            rescue Exception => e
             @logger.error(" caught: #{e.message}")
            end 
        end
    end
    if @normalize
        replant(event, @newroot)
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
        json = JSON.parse("{\"ip\": \""+field+"\"}")
    end
    # @logger.info("json parse option for field #{field} / #{json}")
end

def find(item)
    res = "{}"
    # Is item in list? (list is an optional array)
    #unless list.nil? 
        # What if the list exists, but item is not on the list?
    #    return list[item]
    #end
    # Is item in redis?
    unless @red.nil?
        res = @red.get(item)
	unless res.nil?
            return res
        end
    end

    # find the key where the value is <item>, otherwise just use the value
    current_uri = @uri
    current_uri.query_values = @params.merge({@ip => item})
    #logger.info(@uri.to_s)
    @connpool.with do |conn|
        http_response = conn.request_get(current_uri)
	res = http_response.read_body if http_response.is_a?(Net::HTTPSuccess)
	if res.eql? "null"
            res = "{}"
        end
	#logger.info(res.to_s)
        unless @red.nil?
            @red.set(item, res)
            @red.expire(item,redis_expiry)
        end
    end
    return res
end

# for legacy
def normalize(event)
    event.set("net", JSON.parse(net))
    event.get("[records][properties]").each {|k, v| event.set(k, v) }
    event.remove("[records]")
    event.remove("[message]")
    return event
end

def replant(event, newroot)
    @logger.debug("event: #{event.get(newroot)}")
    event.get(newroot).each {|k, v| event.set(k, v) }
    event.remove(@roottostrip)
    return event
end

# From https://github.com/angel9484/logstash-filter-lookup
def json_loader(data)
    get_map.merge!(JSON.parse(File.read(data)))
end

def csv_loader(data)
    data = CSV.read(data).inject(Hash.new) do |acc, v|
      acc[v[0]] = v[1]
      acc
    end
    get_map.merge!(data)
end

def yml_loader(data)
    get_map.merge!(YAML.load_file(data))
end

end
