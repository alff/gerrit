#
# Cookbook Name:: gerrit
# Recipe:: server
#
# Copyright 2013, Mirantis, IT
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

chef_gem "ruby-mysql" do
  action :install
end

require 'mysql'


::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
if Chef::Config[:solo]
   Chef::Application.fatal!("This version doesn't support solo mode..")
else
  node.set_unless["gerrit"]["db"]["tunable"]["password"] = secure_password
  node.set_unless["gerrit"]["tunable"]["smtp_password"] = secure_password
  node.save
end

# Define some requirement stuff
gerrit_home = node["gerrit"]["home"]
creds = data_bag('users')

# Define hash dictionary
dict={}
dict["auth_type"] = node["gerrit"]["auth_type"]
dict["actual_list"] = []
dict["new_keys"] = 0
dict["new_users"] = 0
dict["updated_keys"] = 0


#jdk instalation
include_recipe "java"

# TODO: Add support of different DB types
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

else
  Chef::Application.fatal!("This version doesn't support that DB type. Please, use MYSQL.")
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

directory "#{gerrit_home}/.ssh" do
  owner node["gerrit"]["user"]
  group "gerrit"
  mode 0700
end

%w{ id_rsa id_rsa.pub }.each do |fl|
  cookbook_file "#{gerrit_home}/.ssh/#{fl}" do
    owner node["gerrit"]["user"]
    group "gerrit"
    mode 0600
  end
end

#gerrit source download
remote_file "#{gerrit_home}/gerrit_distr.war" do
  source "http://gerrit.googlecode.com/files/gerrit-full-#{node["gerrit"]["version"]}.war"
  owner node["gerrit"]["user"]
  group "gerrit"
  mode 0644
  not_if {File.exists?("#{gerrit_home}/gerrit_distr.war")}
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

template "#{node["gerrit"]["tunable"]["gerrit_site"]}/replication.config" do
  source "replication.config.erb"
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

unless node["gerrit"]["init_state"] && node["gerrit"]["init_state"] == "ok"
  if dict["auth_type"] == "HTTP" || dict["auth_type"] == "CAS"
    include_recipe "apache2"
    include_recipe "apache2::mod_auth_cas"
    include_recipe "libapache2-mod-auth-cas"
    %w{ libapache2-mod-proxy-html }.each do |pack|
       include_recipe 'libapache2-mod-auth-cas'
       package pack do
          action :install
       end
    end

    cookbook_file "/etc/apache2/sites-available/gerrit" do
       action :create_if_missing
    end

#TODO: Check block supporting of different linux versions
script "Cooking-apache" do
  interpreter "bash"
  code <<-EOH
a2dissite default
a2ensite gerrit
a2enmod proxy
a2enmod proxy_http
a2enmod auth_cas
  EOH
end
  end


  #TODO: Need to inmprove this part (remove executes and scripts)
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
end

service "gerrit" do
  action [ :enable, :start ]
end

ruby_block "Set-init-state" do
  block do
    node.set_unless["gerrit"]["init_state"] = "ok"
    node.save
    Chef::Log.info "Gerrit site initialized.."
  end
end
end


## PROJECT SETUP ##
service "apache2" do
  action :nothing
end

# This part contains tuned part of user management for ATnT specific environment

case dict["auth_type"]
when "OPENID"
  ruby_block "Setup-users" do
    block do
      creds.each do |cred|
        user = data_bag_item('users', cred)
        if user["gerrit"]
          if user["gerrit"] == "admin"
            is_gerrit_admin = true
            flag = 1
          elsif user["gerrit"] == "user"
            is_gerrit_admin = false
            flag = 3
          else
            Chef::Log.warn "Unknown type of users. Skipping.."
          end
        else
          next
        end
        # Call setup user in db
        dict = manage_users(node["gerrit"]["db"]["type"],dict)
      end
    # Call checking of actual users
        check_users(node["gerrit"]["db"]["type"],dict)
    # Call logger
    log_result(dict)
    end
  end
when "CAS", "HTTP"
  creds = data_bag('users')
  t_group = []
  creds.each do |cred|
    user = data_bag_item('users', cred)
    if user["gerrit"]
      if user["externa_id"]
        t_group.push user["email"]
      else
        t_group.push user["id"]
      end
    else
      next
    end
  # Call setup user in db
  dict = manage_users(node["gerrit"]["db"]["type"],dict)
  end
  # Call checking of actual users
  check_users(node["gerrit"]["db"]["type"],dict)
  # Call logger
  log_result(dict)
  userlist = t_group.join(' ')

  # Ugly workaround with apache reload in Ubuntu.
  # Looks like standart resource does not reload apache service. Too bad. :(
  script "Reload-apache" do
    interpreter "bash"
    code <<-EOH
    service apache2 reload
    EOH
    action :nothing
  end

  template "/etc/apache2/sites-available/gerrit" do
    source "apache.gerrit.erb"
    variables(
      :userlist => userlist
    )
  notifies :run, "script[Reload-apache]"
  end

end
