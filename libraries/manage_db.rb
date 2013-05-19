#!/usr/bin/env ruby

module DBM

  def manage_users(dbtype, attrs={})
    attrs["db_address"] ||= "127.0.0.1"
    attrs["flag"] ||= "3"
    attrs["actual_list"] ||= []
    attrs["new_keys"] ||= 0
    attrs["new_users"] ||= 0
    attrs["updated_keys"] ||= 0
    case dbtype
    when "MYSQL"
      db = Mysql.connect("#{attrs["db_address"]}", "#{node["gerrit"]["db"]["tunable"]["username"]}", "#{node["gerrit"]["db"]["tunable"]["password"]}", "#{node["gerrit"]["db"]["tunable"]["database"]}")
      Chef::Log.info "Connected to DB.."
      query = db.query("SELECT account_id FROM accounts WHERE preferred_email='#{attrs["user"]["email"]}'")
      if query.size >0
        id = query.fetch_row[0].to_i
        ssh_query = db.query("Select account_id FROM account_ssh_keys WHERE account_id=#{id}")
        if ssh_query.size >0
          Chef::Log.info "Update key for user #{attrs["user"]["id"]}."
          update_query = db.query("UPDATE account_ssh_keys SET ssh_public_key='#{attrs["user"]["ssh_keys"]}' WHERE account_id=#{id}")
          attrs["updated_keys"] +=1
        else
          Chef::Log.info "Create new key for user #{attrs["user"]["id"]}."
          create_query = db.query("INSERT INTO `account_ssh_keys` VALUES ('#{attrs["user"]["ssh_keys"]}', 'Y', #{id}, 1)")
          attrs["new_keys"] +=1
        end
        query = db.query("UPDATE `account_group_members` SET group_id=#{attrs["flag"]} WHERE account_id=#{id}")
        query = db.query("UPDATE `account_group_members_audit` SET group_id=#{attrs["flag"]} WHERE account_id=#{id}")
        attrs["ctual_list"].push id
      else
        Chef::Log.info "Start procedure of new user creating with id #{attrs["user"]["id"]}.."
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
        query = db.query("INSERT INTO `accounts` VALUES (CURRENT_TIMESTAMP,'#{attrs["user"]["full_name"]}','#{attrs["user"]["email"]}',NULL,25,'Y','Y',NULL,NULL,'N',NULL,NULL,'N','N','N',#{max_id})")
        # Add new account external ids
        Chef::Log.info "Insert external id.."
        case attrs["auth_type"]
        when "OPENID"
          query = db.query("INSERT INTO `account_external_ids` VALUES (#{max_id},'#{attrs["user"]["email"]}',NULL,'#{attrs["user"]["openid"]}')")
        when "HTTP", "CAS"
          if attrs["user"]["external_id"]
            query = db.query("INSERT INTO `account_external_ids` VALUES (#{max_id},'#{attrs["user"]["email"]}',NULL,'gerrit:#{attrs["user"]["email"]}')")
          else
            query = db.query("INSERT INTO `account_external_ids` VALUES (#{max_id},'#{attrs["user"]["email"]}',NULL,'gerrit:#{attrs["user"]["id"]}')")
          end
        query = db.query("INSERT INTO `account_external_ids` VALUES (#{max_id},'#{attrs["user"]["email"]}',NULL,'username:#{attrs["user"]["id"]}')")
        else
          Chef::Application.fatal!("This version doesn't support this type of authorization. Sorry..")
        end
        # Add full rights to user
        Chef::Log.info "Grant access rights to user.."
        query = db.query("INSERT INTO `account_group_members` VALUES (#{max_id},#{attrs["flag"]})")
        query = db.query("INSERT INTO `account_group_members_audit` VALUES (#{max_id},NULL,NULL,#{max_id},#{attrs["flag"]},CURRENT_TIMESTAMP)")
        # Add ssh keys
        Chef::Log.info "Insert ssh pub key.."
        query = db.query("INSERT INTO `account_ssh_keys` VALUES ('#{attrs["user"]["ssh_keys"]}','Y',#{max_id},1)")
        attrs["new_keys"] +=1
        Chef::Log.info "Procedure of new user creating is complete. Account #{attrs["user"]["id"]} was added.."
        attrs["new_users"] +=1
        attrs["actual_list"].push max_id
      end
    else
      Chef::Application.fatal!("This version doesn't support this type of DB. Sorry..")
    end
    attrs
  end

  def check_users(dbtype, attrs={})
    Chef::Log.info "Disable users which are not in the actual list.."
    case dbtype
    when "MYSQL"
      db = Mysql.connect("#{db_address}", "#{node["gerrit"]["db"]["tunable"]["username"]}", "#{node["gerrit"]["db"]["tunable"]["password"]}", "#{node["gerrit"]["db"]["tunable"]["database"]}")
      enabled_ids = attrs["actual_list"].join(',')
      if enabled_ids.empty?
        Chef::Log.warn "Disabling all users in gerrit."
        query = db.query("UPDATE `accounts` SET inactive='Y'")
      else
        query = db.query("UPDATE `accounts` SET inactive='Y' WHERE `account_id` NOT IN (#{enabled_ids})")
      end
    else
      Chef::Application.fatal!("This version doesn't support this type of DB. Sorry..")
    end
  end

end

class Chef::Resource::RubyBlock
  include DBM
end
