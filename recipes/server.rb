# Recipe installs and configure gerrit server
# with support embeded and external DBs.
#

# author Alex Khalkuziev (akhalkuziev@mirantis.com)

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
if Chef::Config[:solo]
   Chef::Application.fatal!("This version doesn't support solo mode..")
else
  node.set_unless["gerrit"]["db"]["password"] = secure_password
  node.set_unless["gerrit"]["tunable"]["smtp_password"] = secure_password
  node.save
end

gerrit_home = "/home/gerrit"
#jdk instalation
include_recipe "java"

case node["gerrit"]["db"]["type"]
when "MYSQL"
  mysql_server = search(:node, "(role:mysql OR roles:mysql) AND chef_environment:#{node.chef_environment}")
  if mysql_server.size>1
    Chef::Log.fatal!("Hmm.. I think i found the mysql cluster on current environment. Need to define share_ip or target server manually..")
  elsif mysql_server.size == 1
    mysql_server = mysql_server[0]
  else
    include_recipe "mysql::server"
    mysql_server = node
  end
    db_address = mysql_server["mysql"]["bind_address"]
    db_port = mysql_server["mysql"]["port"]
end
if node["gerrit"]["tunable"]["canonical_port"] && node["gerrit"]["tunable"]["canonical_port"] !="80"
  canonical_url = "#{node["gerrit"]["tunable"]["canonical_domain"]}:#{node["gerrit"]["tunable"]["canonical_port"]}"
else
  canonical_url = "#{node["gerrit"]["tunable"]["canonical_domain"]}"
end
if node["gerrit"]["tunable"]["url_listen_port"]
  listen_url = "#{node["gerrit"]["tunable"]["url_listen_address"]}:#{node["gerrit"]["tunable"]["url_listen_port"]}"
else
  listen_url = "#{node["gerrit"]["tunable"]["url_listen_address"]}"
end

group "gerrit"
user node["gerrit"]["user"] do
  comment "Gerrit user"
  home gerrit_home
  gid "gerrit"
  supports(
    :manage_home=>true
  )
end

#gerrit source download
remote_file "#{gerrit_home}/gerrit_distr.war" do
  source "http://gerrit.googlecode.com/files/gerrit-full-#{node["gerrit"]["version"]}.war"
  owner node["gerrit"]["user"]
  group "gerrit"
end

# Prepare gerrit instalation
directory node["gerrit"]["tunable"]["gerrit_site"] do
  owner node["gerrit"]["user"]
  group "gerrit"
end
directory "#{node["gerrit"]["tunable"]["gerrit_site"]}/etc" do
  owner node["gerrit"]["user"]
  group "gerrit"
  action :create
end

template "#{node["gerrit"]["tunable"]["gerrit_site"]}/etc/gerrit.config" do
  source "gerrit.config.erb"
  owner node["gerrit"]["user"]
  group "gerrit"
  variables(
    :db_address =>db_address,
    :db_port =>db_port,
    :canonical_url =>canonical_url,
    :listen_url =>listen_url
  )
end

template "#{node["gerrit"]["tunable"]["gerrit_site"]}/etc/secure.config" do
  source "secure.config.erb"
  group "gerrit"
  owner node["gerrit"]["user"]
  mode "0600"
end

template "#{node["gerrit"]["init"]["config"]}/gerritcodereview" do
  source "gerritcodereview.erb"
  owner node["gerrit"]["user"]
  group "gerrit"
  variables(
    :no_start =>node["gerrit"]["tunable"]["no_start"],
    :daemon_mode => node["gerrit"]["tunable"]["daemon_mode"]
  )
end

# This template won't proccessed on external mysql server without grant access of this node
template "#{gerrit_home}/mysql_script.sql" do
  source "mysql_script.sql.erb"
  owner node["gerrit"]["user"]
  group "gerrit"
  variables(
    :db_address =>db_address
  )
end

execute "Create-gerrit-DB" do
  case node["gerrit"]["db"]["type"]
  when "MYSQL"
    command "#{mysql_server['mysql']['mysql_bin']} -u root -p\"#{mysql_server['mysql']['server_root_password']}\" < #{gerrit_home}/mysql_script.sql"
  end
end
script "install-gerrit-package" do
  interpreter "bash"
  user node["gerrit"]["user"]
  group "gerrit"
  cwd gerrit_home
code <<-EOH
java -jar #{gerrit_home}/gerrit_distr.war init -d #{node["gerrit"]["tunable"]["gerrit_site"]} --batch
EOH
end

script "Enable-gerrit-service" do
  interpreter "bash"
  code <<-EOH
ln -snf #{node["gerrit"]["tunable"]["gerrit_site"]}/bin/gerrit.sh #{node["gerrit"]["init"]["bin"]}/gerrit
  EOH
#ln -snf #{node["gerrit"]["init"]["bin"]}/gerrit #{node["gerrit"]["init"]["run_level"]}/S90gerrit
end
service "gerrit" do
  action [:enable, :start]
end

## PROJECT SETUP ##



