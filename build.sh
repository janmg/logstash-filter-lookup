pushd ..
/usr/share/logstash/bin/logstash-plugin remove logstash-filter-lookup
popd
sudo -u logstash gem build logstash-filter-lookup.gemspec 
sudo -u logstash gem install logstash-filter-lookup-0.1.0.gem
pushd ..
/usr/share/logstash/bin/logstash-plugin install logstash-filter-lookup/logstash-filter-lookup-0.1.0.gem
popd
sudo -u logstash rspec
/usr/share/logstash/bin/logstash -f test.conf --config.reload.automatic
