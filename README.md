gerrit
======

Install gerrit service

# Annotation

This cookbook installs gerrit as a service.
This recipe depends from 'java' cookbook and this dependency was setted in gerrit role (see Usage section).All settings could be overwritten by cookbook atributes, role or environment attributes.
Userlist takes from yaml file from 'cookbook_file' section but it could be changed on any different path other information about users takes from data bags.
Example of supported data bags and yaml lists attached with cookbook and could be obtained in 'databag/' and 'files/' folders.



 # Usage

1. Download 'java' coobook from opscode community or from my github account.
2. Create role 'java' and set preffered flavor of java ('openjdk' or 'sun') in role attrinutes and upload it on chef server.
    Example:
            {
              "name": "java",
              "description": "",
              "json_class": "Chef::Role",
              "default_attributes": {
               },
              "override_attributes": {
                "java": {
                  "oracle": {
                     "accept_oracle_download_terms": true
                        },
                  "install_flavor": "oracle"
                  }
               },
              "chef_type": "role",
              "run_list": [
              "recipe[java]"
              ],
              "env_run_lists": {
               }
            }

(see manual for 'java' cookbook)

3. Create role gerrit.
    Example:
            {
              "name": "gerrit",
              "description": "",
              "json_class": "Chef::Role",
              "default_attributes": {
              },
              "override_attributes": {
                "gerrit": {
                   "db": {
                     "type": "MYSQL"
                    },
                   "auth_type": "OPENID"
                }
              },
            "chef_type": "role",
            "run_list": [
               "role[java]",
                  "recipe[gerrit::server]"
            ],
            "env_run_lists": {
              }
           }
4. Upload roles on chef server and attach role 'gerrit' to target node.
5. Start chef-client
