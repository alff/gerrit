#
# Cookbook Name:: gerrit
# Recipe:: default
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

# Default set of gerrit attributes
# Version of gerrit
default["gerrit"]["version"] = "2.5.1"

# Home
default["gerrit"]["home"] = "/home/gerrit"

# Container
default["gerrit"]["user"] = "gerrit"

##ATT stuff##
#NOTE: Move to role or env attributes at the best
default["gerrit"]["att"]["cas_url"] = "https://sso.sl.attcompute.com/cas/login"
default["gerrit"]["att"]["cas_validate_url"] = "https://sso.sl.attcompute.com/cas/serviceValidate"

# Some values
default["gerrit"]["tunable"]["gerrit_site"] = "/opt/gerrit"
# In some cases you could set 'fqdn' instead of 'ipaddress'
default["gerrit"]["tunable"]["canonical_domain"] = ipaddress
default["gerrit"]["tunable"]["canonical_port"] = "80"

# If we won't start gerrit set 'on'
default["gerrit"]["tunable"]["no_start"] = 0

# Init daemon enable
default["gerrit"]["tunable"]["daemon_mode"] = 0

# Tuning
default["gerrit"]["tunable"]["packet_git_limit"] = "1024m"
default["gerrit"]["tunable"]["packet_windows_sz"] = "16k"
default["gerrit"]["tunable"]["stream_treshold"] = "512m"
default["gerrit"]["tunable"]["heap_limit"] = "1380m"
# SSH
default["gerrit"]["tunable"]["ssh_listen_address"] = "*"
default["gerrit"]["tunable"]["ssh_listen_port"] = "29418"
# HTTP
default["gerrit"]["tunable"]["url_listen_address"] = "127.0.0.1"
default["gerrit"]["tunable"]["url_listen_port"] = "8080"
# SMTP
default["gerrit"]["tunable"]["smtp_server"] = "localhost"
default["gerrit"]["tunable"]["smtp_user"] = "gerrit"
# DB
case node["gerrit"]["db"]["type"]
when "MYSQL"
  default["gerrit"]["db"]["type"] = "MYSQL"
  default["gerrit"]["db"]["tunable"]["database"] = "reviewdb"
  default["gerrit"]["db"]["tunable"]["username"] = "gerrit"
end
# Gerrit
default["gerrit"]["tunable"]["base_path"] = "git"

case node["platform"]
when "ubuntu"
  default["gerrit"]["init"]["config"] = "/etc/default"
  default["gerrit"]["init"]["bin"] = "/etc/init.d"
  default["gerrit"]["init"]["run_level"] = "/etc/rc3.d"
end
