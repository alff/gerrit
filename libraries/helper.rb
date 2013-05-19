#!/usr/bin/env ruby

module HELPER
  def log_result(attrs={})
    Chef::Log.info "#{node["gerrit"]["auth_type"]} auth mode was enabled.."
    Chef::Log.info "New users created: #{attrs["new_users"]}."
    Chef::Log.info "New keys added: #{attrs["new_keys"]}."
    Chef::Log.info "Keys updated: #{attrs["updated_keys"]}."
    puts ""
    puts "New users created: #{attrs["new_users"]}."
    puts "New keys added: #{attrs["new_keys"]}."
    puts "Keys updated: #{attrs["updated_keys"]}."
    sleep 5
  end
end


class Chef::Resource::RubyBlock
    include HELPER
end
class Chef::Recipe
    include HELPER
end
