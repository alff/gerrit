name             "gerrit"
maintainer       "AT&T Services, Inc."
maintainer_email "cookbooks@lists.tfoundry.com"
license          "Apache 2.0"
description      "Installs/Configures gerrit"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.2.5"

recipe           "gerrit::server", "Installs/Configures gerrit"

supports         "ubuntu"

depends          "java"
depends          "libapache2-mod-auth-cas"
depends          "mysql"
