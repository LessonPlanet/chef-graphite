include_recipe "git"

execute "checkout graphiti" do
  command "git clone git://github.com/paperlesspost/graphiti.git graphiti.lessonplanet.com"
  creates "/var/www/graphiti.lessonplanet.com"
  cwd "/var/www"
end

s3_creds = Chef::EncryptedDataBagItem.load('passwords', 'amazon_s3')
template "/var/www/graphiti.lessonplanet.com/config/amazon_s3.yml" do
  owner "deploy"
  mode "0600"
  source "amazon_s3.yml.erb"
  variables :bucket => 'lessonplanet-graphiti', :access_key_id => s3_creds['access_key_id'], :secret_access_key => s3_creds['secret_access_key']
end

template "/var/www/graphiti.lessonplanet.com/config/settings.yml" do
  owner "deploy"
  mode "0600"
  source "settings.yml.erb"
end

execute "graphiti-perms" do
  cwd "/var/www/graphiti.lessonplanet.com"
  user "root"
  command "chown -R deploy:deploy *"
end

gem "bundler"

execute "graphiti-bundler" do
  cwd "/var/www/graphiti.lessonplanet.com"
  user "deploy"
  command "bundle install --deployment --without development test"
end

execute "graphiti-metrics" do
  cwd "/var/www/graphiti.lessonplanet.com"
  user "deploy"
  command "bundle exec rake graphiti:metrics"
end

web_app 'graphiti' do
  docroot "/var/www/graphiti.lessonplanet.com/public"
  server_aliases []
  server_name "graphiti.lessonplanet.com"
  template 'graphiti_web_app.conf.erb'
  rack_env 'production'
end
