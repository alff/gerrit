name             'gerrit'
maintainer       'Mirantis, IT'
maintainer_email 'akhalkuziev@mirantis.com'
license          'All rights reserved'
description      'Installs/Configures gerrit'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

%w{ java mysql }.each do |dep|
  depends dep
end
