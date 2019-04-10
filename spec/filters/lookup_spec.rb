# encoding: utf-8
require_relative '../spec_helper'
require 'logstash/filters/lookup'
require 'redis'

class LogStash::Codecs::JSON
end

describe LogStash::Filters::Lookup do
    describe "test ip lookup" do
    let(:config) do <<-CONFIG
      filter {
        lookup {
          fields => ["ClientIP"]
          list => {
	     '127.0.0.1' => '{"ip":"127.0.0.1", "subnet":"127.0.0.0/8", "netname":"localnet", "hostname"="localhost"}'
	     '192.168.0.1' => '{"ip":"192.168.0.1", "subnet":"192.168.0.0/24", "netname":"private", "hostname":"router"}'
          }
        }
      }
    CONFIG
    end

    message = '{"ClientIP" : "23.100.57.65"}'
    sample("message" => message) do
        #insist { subject["clientIP"][0].to_s } == "192.168.0.1"
	insist { find(subject["ClientIP"]) } == '{"ip":"192.168.0.1", "subnet":"192.168.0.0/24", "netname":"private", "hostname":"router"}'
    end

    sample("message" => message) do
        #ip = subject[fields][0].to_s
	ip = '23.100.57.65'
        @red = Redis.new
        @red.del(ip)
	insist { find(ip) } == '{"ip":"23.100.57.65","netname":"Azure europenorth","subnet":"23.100.48.0\/20","hostname":"monitoring"}'
	@red.del(ip)
	@red.add(ip,'{"ip":"23.100.57.65","netname":"dummy"}')
        insist { find(ip) } == '{"ip":"23.100.57.65","netname":"dummy"}'
	@red.del(ip)
    end
  end
end
