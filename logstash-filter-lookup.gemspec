Gem::Specification.new do |s|
  s.name          = 'logstash-filter-lookup'
  s.version       = '0.1.0'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'This logstash filter plugin takes one or more fields and enriches with a lookup value from a list, redis cache or webservice'
  s.description   = <<-EOF
 This gem is a Logstash plugin. During filter it takes one or more fields and uses that as input to query additional information. The original purpose is to enrich IP addresses with matching subnet, netname and hostname, but it is generic so that any field can be looked up. The function is similar to the translate filter's dictionary lookup, which supports files and regex. The jdbc_streaming filter plugin is also very useful if the data resides in a database. This plugins features are web based lookups and redis caching, for fast lookups.
 The minimal logstash pipeline configuration would look like this
> filter {
>   lookup {
>        fields => ['ClientIP']
>        lookup => "http://127.0.0.1/ripe.php?ip=<item>&TOKEN=token"
>   }
> }
EOF
  s.homepage      = 'https://github.com/janmg/logstash-filter-lookup'
  s.authors       = ['Jan Geertsma']
  s.email         = 'jan@janmg.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }

  # Gem dependencies
  s.add_runtime_dependency 'logstash-core-plugin-api', '~> 2.0'
  s.add_runtime_dependency 'connection_pool', '~> 2.2'
  #s.add_runtime_dependency 'addressable', '~> 2.3.8'
  s.add_development_dependency 'logstash-devutils', '~> 0'
end
