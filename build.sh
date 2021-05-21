GEMPWD=$(pwd)
#PROGRAM=${GEMPWD##*/}
PROGRAM=$(grep name *.gemspec | head -1 | cut -d"'" -f 2)
VERSION=$(grep version ${PROGRAM}.gemspec | cut -d"'" -f 2)

echo "Building ${PROGRAM} ${VERSION}"
pushd /usr/share/logstash 
/usr/share/logstash/bin/logstash-plugin remove ${PROGRAM}
popd
sudo -u logstash gem build ${PROGRAM}.gemspec 
sudo -u logstash gem install ${PROGRAM}-${VERSION}.gem
/usr/share/logstash/bin/logstash-plugin install ${GEMPWD}/logstash-filter-weblookup-0.1.3.gem
#sudo -u logstash rspec
#/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/test.conf --config.reload.automatic
#gem publish ${PROGRAM}-${VERSION}.gem
