pushd /usr/share/logstash 
/usr/share/logstash/bin/logstash-plugin remove logstash-filter-weblookup
popd
sudo -u logstash gem build logstash-filter-weblookup.gemspec 
sudo -u logstash gem install logstash-filter-weblookup-0.1.2.gem
/usr/share/logstash/bin/logstash-plugin install /usr/src/logstash-filter-weblookup/logstash-filter-weblookup-0.1.2.gem
#sudo -u logstash rspec
#/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/test.conf --config.reload.automatic
