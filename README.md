gerrit
======

Installs/Configures gerrit

# Annotation

This cookbook installs gerrit as a service.
This recipe depends from 'java' cookbook and this dependency was setted in gerrit role (see Usage section).All settings could be overwritten by cookbook atributes, role or environment attributes.
Userlist takes from yaml file from 'cookbook_file' section but it could be changed on any different path other information about users takes from data bags.
Example of supported data bags and yaml lists attached with cookbook and could be obtained in 'databag/' and 'files/' folders.

Usage
=====

server
----

Installs/Configures gerrit

```json
"run_list": [
    "recipe[gerrit::server]"
]
```

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

!!!!!!WARNING!!!!!!!
Temporary at first run attributes from role 'gerrit' doesn't work because they are saving when recipe compile time starts. But attributes from recipe are trying
to check variable of attribute from role. Espesially dbtype and auth method. Need to set it manualy.
!!!!!!!!!!!!!!!!!!!!

4. Upload roles on chef server and attach role 'gerrit' to target node.
5. Start chef-client

Testing
=====

This cookbook is using [ChefSpec](https://github.com/acrmp/chefspec) for 
testing. Run the following before commiting. It will run your tests,
and check for lint errors.

    % ./run_tests.bash

License and Author
==================

Author:: Alex Khalkuziev (<akhalkuziev@mirantis.com>)

Copyright 2013, Mirantis, IT
Copyright 2013, AT&T Services, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and⋅
    limitations under the License.
