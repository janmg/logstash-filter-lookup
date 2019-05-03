pushd /usr/share/logstash 
/usr/share/logstash/bin/logstash-plugin remove logstash-filter-lookup
popd
sudo -u logstash gem build logstash-filter-lookup.gemspec 
sudo -u logstash gem install logstash-filter-lookup-0.1.0.gem
/usr/share/logstash/bin/logstash-plugin install /usr/src/logstash-filter-lookup/logstash-filter-lookup-0.1.0.gem
#sudo -u logstash rspec
/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/nsg-blab-ddm-ne.conf --config.reload.automatic
