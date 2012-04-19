package node[:graphite][:twisted_package]
package node[:graphite][:simplejson_package]
case node[:platform]
when "redhat","centos"
  %w(python-devel python-crypto pyOpenSSL zope).each do |pkg|
    package pkg
  end
end

version = node[:graphite][:version]
pyver = node[:graphite][:python_version]

remote_file "/usr/src/Twisted-11.1.0.tar.bz2" do
  source 'http://twistedmatrix.com/Releases/Twisted/11.1/Twisted-11.1.0.tar.bz2'
end

execute "untar twisted" do
  command "tar xjf Twisted-11.1.0.tar.bz2"
  creates "/usr/src/Twisted-11.1.0"
  cwd "/usr/src"
end

execute "install twisted" do
  command "python setup.py install"
  creates '/usr/lib64/python2.4/site-packages/Twisted-11.1.0-py2.4-linux-x86_64.egg'
  cwd "/usr/src/Twisted-11.1.0"
end

remote_file "/usr/src/carbon-#{version}.tar.gz" do
  source node[:graphite][:carbon][:uri]
  checksum node[:graphite][:carbon][:checksum]
end

execute "untar carbon" do
  command "tar xzf carbon-#{version}.tar.gz"
  creates "/usr/src/carbon-#{version}"
  cwd "/usr/src"
end

execute "install carbon" do
  command "python setup.py install"
  creates "/opt/graphite/lib/carbon"
  cwd "/usr/src/carbon-#{version}"
end

template "/opt/graphite/conf/carbon.conf" do
  owner node['apache']['user']
  group node['apache']['group']
  variables( :line_receiver_interface => node[:graphite][:carbon][:line_receiver_interface],
             :pickle_receiver_interface => node[:graphite][:carbon][:pickle_receiver_interface],
             :cache_query_interface => node[:graphite][:carbon][:cache_query_interface] )
  notifies :restart, "service[carbon-cache]"
end

template "/opt/graphite/conf/storage-schemas.conf" do
  owner node['apache']['user']
  group node['apache']['group']
  notifies :restart, 'service[carbon-cache]'
end

execute "carbon: change graphite storage permissions to apache user" do
  command "chown -R #{node['apache']['user']}:#{node['apache']['group']} /opt/graphite/storage"
  only_if do
    f = File.stat("/opt/graphite/storage")
    f.uid == 0 and f.gid == 0
  end
end

directory "/opt/graphite/lib/twisted/plugins/" do
  owner node['apache']['user']
  group node['apache']['group']
end

case node[:platform]
when "redhat","centos"
  template "/etc/init.d/carbon-cache" do
    source 'carbon-cache.init.erb'
    mode 0755
    owner 'root'
  end
  service "carbon-cache" do
    supports :status => true, :restart => true
    action [ :enable, :start ]
  end
else
  runit_service "carbon-cache" do
    finish_script true
  end
end
