#
# Cookbook Name:: testactivemq
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

tmp = Chef::Config[:file_cache_path]
version = node['activemq']['version']
mirror = node['activemq']['mirror']
activemq_home = "#{node['activemq']['home']}/apache-activemq-#{version}"

directory node['activemq']['home'] do
  recursive true
end

unless File.exists?("#{activemq_home}/bin/activemq")
  remote_file "#{tmp}/apache-activemq-#{version}-bin.tar.gz" do
    source "#{mirror}/activemq/#{version}/apache-activemq-#{version}-bin.tar.gz"
    mode "0644"
  end

  execute "tar zxf #{tmp}/apache-activemq-#{version}-bin.tar.gz" do
    cwd node['activemq']['home']
  end
end

file "#{activemq_home}/bin/activemq" do
  owner "root"
  group "root"
  mode "0755"
end

# TODO: make this more robust
arch = (node['kernel']['machine'] == "x86_64") ? "x86-64" : "x86-32"

link "/etc/init.d/activemq" do
  to "#{activemq_home}/bin/linux-#{arch}/activemq"
end

template "activemq.xml" do
  source "activemq.xml.erb"
  mode "0755"
  path "#{activemq_home}/conf/activemq.xml"
  action :create
  notifies :restart, 'service[activemq]'
end

service "activemq" do
  supports  :restart => true, :status => true
  action [:enable, :start]
end

# symlink so the default wrapper.conf can find the native wrapper library
link "#{activemq_home}/bin/linux" do
  to "#{activemq_home}/bin/linux-#{arch}"
end

# symlink the wrapper's pidfile location into /var/run
link "/var/run/activemq.pid" do
  to "#{activemq_home}/bin/linux/ActiveMQ.pid"
  not_if "test -f /var/run/activemq.pid"
end

template "#{activemq_home}/bin/linux/wrapper.conf" do
  source "wrapper.conf.erb"
  mode 0644
  variables(:pidfile => "/var/run/activemq.pid")
  notifies :restart, 'service[activemq]'
end
