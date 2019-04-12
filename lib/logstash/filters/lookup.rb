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
  config :destinations, :validate => :array, :required => false

  config :lookup, :validate => :string, :required => false, :default => "http://localhost/ripe.php?ip=<item>&TOKEN=token"

  # Optional ruby hash with the key as a string and the value as a string in the form of a JSON object. These key's will not be looked up.
  config :list, :validate => :hash, :required => false

  # Optional Redis IP cache
  config :use_redis, :validate => :boolean, :required => false, :default => false
  config :redis_expiry, :validate => :number, :required => false, :default => 604800 

  HTTP_OPTIONS = {
      keep_alive_timeout: 300
  }

public
def register
    if use_redis
        @red = Redis.new
    end
    @uri = Addressable::URI.parse(lookup)
    @uri.merge!(HTTP_OPTIONS)
    #@http = Net::HTTP.new(uri.host, uri.port, HTTP_OPTIONS)
    #@uri.port=80 if (@uri.port.nil? && @uri.scheme=="http")
    #@uri.port=443 if (@uri.port.nil? && @uri.scheme=="https")
    @connpool = ConnectionPool.new(size: 2, timeout: 180) { 
        Net::HTTP.new(@uri.host, @uri.port)
    }
end # def register



#  def initialize(http = nil)
#    if http
#      @http = http
#    else
#      @http = Net::HTTP.start("", 443, HTTP_OPTIONS)
#    end
#  end

  #def fetch(id, file)
  #  response = @http.request Net::HTTP::Get.new "/gists/#{id}"
  #  JSON.parse(response.body)["files"][file]["content"]
  #end


def filter(event)
    fields.each_with_index do |field, index|
        # @logger.info(event.get("["+field+"]"))
	x = find(event.get(field).to_s)
	begin
            json = JSON.parse(x)
	rescue JSON::ParserError
            json = x
	end    
        event.set("["+destinations[index]+"]", json)
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
    params = @uri.query_values(Hash)
    params.each do |key, value|
        params.merge!sub(key, value, item)
    end
    @uri.query_values=(params)

    @logger.info(@uri)
    @connpool.with do |conn|
        res = conn.request_get(@uri).read_body
    end
    #return res.read_body
    unless @red.nil?
        @red.set(item, res)
        @red.expire(item,redis_expiry)
    end
    return res
end

private
def sub(key, value, item)
    return {key => item} if value=="\<item\>"
    return {key => value}
end

end # class LogStash::Filters::Lookup
