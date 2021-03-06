define append_if_no_such_line($file, $line, $refreshonly = 'false') {
   exec { "/bin/echo '$line' >> '$file'":
      unless      => "/bin/grep -Fxqe '$line' '$file'",
      path        => "/bin",
      refreshonly => $refreshonly,
   }
}

class must-have {
  include apt
  apt::ppa { "ppa:webupd8team/java": }

  exec { 'apt-get update':
    command => '/usr/bin/apt-get update',
    before => Apt::Ppa["ppa:webupd8team/java"],
  }

  exec { 'apt-get update 2':
    command => '/usr/bin/apt-get update',
    require => [ Apt::Ppa["ppa:webupd8team/java"], Package["git-core"] ],
  }

  package { ["vim",
             "curl",
             "git-core",
             "bash"]:
    ensure => present,
    require => Exec["apt-get update"],
    before => Apt::Ppa["ppa:webupd8team/java"],
  }

  package { ["oracle-java7-installer"]:
    ensure => present,
    require => Exec["apt-get update 2"],
  }

  exec {
    "accept_license":
    command => "echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections && echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections",
    cwd => "/home/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Package["curl"],
    before => Package["oracle-java7-installer"],
    logoutput => true,
  }

  exec {
    "download_stash":
    command => "curl -L http://www.atlassian.com/software/stash/downloads/binary/atlassian-stash-2.8.2.tar.gz | tar zx",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Exec["accept_license"],
    logoutput => true,
    creates => "/vagrant/atlassian-stash-2.8.2",
  }

  exec {
    "create_stash_home":
    command => "mkdir -p /vagrant/stash-home",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Exec["download_stash"],
    logoutput => true,
    creates => "/vagrant/stash-home",
  }

  exec {
    "start_stash_in_background":
    environment => "STASH_HOME=/vagrant/stash-home",
    command => "/vagrant/atlassian-stash-2.8.2/bin/start-stash.sh &",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => [ Package["oracle-java7-installer"],
                 Exec["accept_license"],
                 Exec["download_stash"],
                 Exec["create_stash_home"] ],
    logoutput => true,
  }

  append_if_no_such_line { motd:
    file => "/etc/motd",
    line => "Run Stash with: STASH_HOME=/vagrant/stash-home /vagrant/atlassian-stash-2.8.2/bin/start-stash.sh",
    require => Exec["start_stash_in_background"],
  }
}

include must-have


include apt

# this repo is needed vor collectd version 5.3
apt::ppa { "ppa:vbulax/collectd5": }

exec { "apt-update":
  command => '/usr/bin/apt-get update',
  user => root,
  require => Apt::Ppa["ppa:vbulax/collectd5"],
}


class { '::collectd':
  require => Exec["apt-update"]
}

include collectd

class { 'collectd::plugin::write_graphite':
  graphitehost => '10.0.2.2',
}
