Exec {
  path => [
    '/usr/local/bin',
    '/opt/local/bin',
    '/usr/bin',
    '/usr/sbin',
    '/bin',
    '/sbin',
    '/opt/vagrant_ruby/bin'
  ],
  #logoutput => true,
}

stage { 'first':
  before => Stage['main'],
}

class { 'prepare':
  stage => first;
}

/**
 * System Prepare
 */

class prepare {
  exec { 'mongodb-import-public-key':
    command => 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10',
    user => 'root',
    group => 'root',
  }

  exec { 'mongodb-create-list-file':
    command => "echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list",
    require => Exec['mongodb-import-public-key'],
  }

  package { 'curl':
    ensure => present,
  }

  exec { 'node-setup':
    command => 'curl -sL https://deb.nodesource.com/setup | sudo bash -',
    require => Package['curl'],
  }
}


/**
 * System Configuration
 */

class system {
  exec { 'apt-get update': }

  $apps = [
  	'build-essential',
  	'git',
  	'nodejs',
    'libjpeg-dev',
    'libpng-dev',
  	'libnotify-bin',
    'mongodb-org'
  ]

  package { $apps:
    ensure => present,
    require => [Class['prepare'], Exec['apt-get update']],
  }

  package { 'dnsmasq':
    ensure  => installed,
    require => Package[$apps],
  }

  file { '/etc/dnsmasq.conf':
    ensure => file,
    source => '/vagrant/files/etc/dnsmasq.conf',
    force  => true,
    require => Package['dnsmasq'],
    notify => Service['dnsmasq'],
  }

  file { '/etc/resolver':
    ensure => directory,
    source => '/vagrant/files/etc/resolver',
    force  => true,
    require => Package['dnsmasq'],
    notify => Service['dnsmasq'],
  }

  # ensure dnsmasq service is up and running
  service { 'dnsmasq':
    ensure => running,
    enable => true,
    hasrestart => true,
    restart => 'service dnsmasq restart',
    require => [Package['dnsmasq'], File['/etc/resolver'], File['/etc/dnsmasq.conf']],
  }

  exec { 'npm install -g gulp bower strongloop':
    require => Package['nodejs'],
  }
}

/**
 * Nginx Configuration
 */

class nginx
{
  $apps = [
    'nginx',
  ]

  package { 'nginx':
    name => $apps,
    ensure => 'latest',
  }

  file { '/etc/nginx/nginx.conf':
    ensure => file,
    source => '/vagrant/files/etc/nginx/nginx.conf',
    force  => true,
    require => [Package['nginx']],
    notify => Service['nginx'],
  }

  file { '/etc/nginx/sites-available/':
    ensure => directory,
    source => '/vagrant/files/etc/nginx/sites-available/',
    force  => true,
    recurse => true,
    require => [Package['nginx']],
    notify => Service['nginx'],
  }

  exec { 'enable-sites':
    command => 'rm -f /etc/nginx/sites-enabled/*.conf && ln -s /etc/nginx/sites-available/*.conf /etc/nginx/sites-enabled/',
    user => 'root',
    group => 'root',
    require => [Package['nginx'], File['/etc/nginx/sites-available/']],
    notify => Service['nginx'],
  }

  file { '/etc/nginx/conf.d/':
    ensure => directory,
    source => '/vagrant/files/etc/nginx/conf.d/',
    force  => true,
    recurse => true,
    require => [Package['nginx']],
    notify => Service['nginx'],
  }

  # ensure apache service is up and running
  service { 'nginx':
    ensure => running,
    enable => true,
    hasrestart => true,
    restart => 'service nginx restart',
    require => Package['nginx'],
  }
}

include prepare
include system
include nginx
