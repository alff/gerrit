# Recipe installs and configure gerrit server
# with support embeded and external DBs.
#

# author Alex Khalkuziev (akhalkuziev@mirantis.com)

chef_gem "ruby-mysql" do
  action :install
end

require 'mysql'
require 'yaml'


::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
if Chef::Config[:solo]
   Chef::Application.fatal!("This version doesn't support solo mode..")
else
  node.set_unless["gerrit"]["db"]["tunable"]["password"] = secure_password
  node.set_unless["gerrit"]["tunable"]["smtp_password"] = secure_password
  node.save
end

gerrit_home = node["gerrit"]["home"]
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
# TODO: Split CAS, HTTP and OPENID  auth as separate attributes. Will be in next version.
# TODO: Use Apache cookbook instead of that temporary workaround
%w{ apache2 libapache2-mod-proxy-html libapache2-mod-auth-cas }.each do |pack|
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

service "apache2" do
  action [:enable, :start ]
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


#ci_file = cookbook_file "/tmp/infrastructure-users-ci.yml" do
#  action :nothing
#end
#ci_file.run_action(:create)
#ci_databags = YAML.load_file('/tmp/infrastructure-users-ci.yml')
#ci_items = ci_databags["data bags"][0]
#ci_users = ci_items["users"]["items"]



case node["gerrit"]["auth_type"]
when "OPENID"
  # Need add correct name for openid item and email
  creds = data_bag('users')
  ruby_block "Check-users" do
    block do
      db = Mysql.connect("#{db_address}", "#{node["gerrit"]["db"]["tunable"]["username"]}", "#{node["gerrit"]["db"]["tunable"]["password"]}", "#{node["gerrit"]["db"]["tunable"]["database"]}")
      actual_list = []
      new_keys = 0
      new_users = 0
      updated_keys = 0
      Chef::Log.info "Connected to DB.."
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
        # DEBUG mock
        unless user["email"]
          user["email"] = "#{user["id"]}@alff.org"
        end
        unless user["openid"]
          user["openid"] = user["id"]
        end
        unless user["full_name"]
          user["full_name"] = user["id"]
        end
        # End of mock
        query = db.query("SELECT account_id FROM accounts WHERE preferred_email='#{user["email"]}'")
        if query.size >0
          id = query.fetch_row[0].to_i
          ssh_query = db.query("Select account_id FROM account_ssh_keys WHERE account_id=#{id}")
          if ssh_query.size >0
            Chef::Log.info "Update key for user #{user["id"]}."
            update_query = db.query("UPDATE account_ssh_keys SET ssh_public_key='#{user["ssh_keys"]}' WHERE account_id=#{id}")
            updated_keys +=1
          else
            Chef::Log.info "Create new key for user #{user["id"]}."
            create_query = db.query("INSERT INTO `account_ssh_keys` VALUES ('#{user["ssh_keys"]}', 'Y', #{id}, 1)")
            new_keys +=1
          end
          query = db.query("UPDATE `account_group_members` SET group_id=#{flag} WHERE account_id=#{id}")
          query = db.query("UPDATE `account_group_members_audit` SET group_id=#{flag} WHERE account_id=#{id}")
          actual_list.push id
        else
          Chef::Log.info "Start procedure of new user creating with id #{user["id"]}.."
          query = db.query("SELECT MAX(account_id) FROM accounts")
          unless query.fetch_row[0]
            max_id = 0
          else
            query = db.query("SELECT MAX(account_id) FROM accounts")
            max_id = query.fetch_row[0].to_i
          end
          max_id +=1
          # Create new uniq id
          query = db.query("INSERT INTO `account_id` VALUES (#{max_id})")
          Chef::Log.info "Inserting new id.."
          # Add new account
          Chef::Log.info "Creating new account.."
          query = db.query("INSERT INTO `accounts` VALUES (CURRENT_TIMESTAMP,'#{user["full_name"]}','#{user["email"]}',NULL,25,'Y','Y',NULL,NULL,'N',NULL,NULL,'N','N','N',#{max_id})")
          # Add new account external ids
          Chef::Log.info "Insert external id.."
          query = db.query("INSERT INTO `account_external_ids` VALUES (#{max_id},'#{user["email"]}',NULL,'#{user["openid"]}')")
          # Add full rights to user
          Chef::Log.info "Grant access rights to user.."
          query = db.query("INSERT INTO `account_group_members` VALUES (#{max_id},#{flag})")
          query = db.query("INSERT INTO `account_group_members_audit` VALUES (#{max_id},NULL,NULL,#{max_id},#{flag},CURRENT_TIMESTAMP)")
          # Add ssh keys
          Chef::Log.info "Insert ssh pub key.."
          query = db.query("INSERT INTO `account_ssh_keys` VALUES ('#{user["ssh_keys"]}','Y',#{max_id},1)")
          new_keys +=1
          Chef::Log.info "Procedure of new user creating is complete. Account #{user["id"]} was added.."
          new_users +=1
          actual_list.push max_id
        end
      end
      Chef::Log.info "Disable users which are not in the actual list.."
      db = Mysql.connect("#{db_address}", "#{node["gerrit"]["db"]["tunable"]["username"]}", "#{node["gerrit"]["db"]["tunable"]["password"]}", "#{node["gerrit"]["db"]["tunable"]["database"]}")
      enabled_ids = actual_list.join(',')
      if enabled_ids.empty?
        Chef::Log.warn "Disabling all users in gerrit."
        query = db.query("UPDATE `accounts` SET inactive='Y'")
      else
        query = db.query("UPDATE `accounts` SET inactive='Y' WHERE `account_id` NOT IN (#{enabled_ids})")
      end
      Chef::Log.info "New users created: #{new_users}."
      Chef::Log.info "New keys added: #{new_keys}."
      Chef::Log.info "Keys updated: #{updated_keys}."
      puts ""
      puts "New users created: #{new_users}."
      puts "New keys added: #{new_keys}."
      puts "Keys updated: #{updated_keys}."
      sleep 5
    end
  end
when "HTTP"
  ruby_block "Info-mode" do
  block do
    Chef::Log.info "HTTP auth mode was enabled.."
  end
  end
when "CAS"
  creds = data_bag('users')
  t_group = []
  creds.each do |cred|
    user = data_bag_item('users', cred)
    if user["gerrit"]
      # FIXME: Workaround for mirantis users whose don't have global UID
      if user["id"] == 'alff' || user["id"] == 'yorik'
        t_group.push user["email"]
      else
        t_group.push user["id"]
      end
    else
      next
    end
  end
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

  #NOTE: Think about correct set admin rights in gerrit. Add in next version
  ruby_block "Info-mode" do
  block do
    Chef::Log.info "CAS auth mode was enabled.."
  end
  end
end
