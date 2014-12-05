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
    'pkg-config',
    'autoconf',
    'libxml2-dev',
    'libssl-dev',
    'libcurl4-openssl-dev',
    'libjpeg-dev',
    'libpng12-dev',
    'libfreetype6-dev',
    'libmcrypt-dev',
  	'libnotify-bin',
    'git',
    'nodejs',
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

/**
 * PHP Configuration
 */

class php
{
  $phpVersion = '5.6.3'
  $phpVersionPath = '5.6'

  exec { 'download php':
    command => "wget -qnv http://pt2.php.net/distributions/php-${phpVersion}.tar.gz",
    cwd => '/home/vagrant',
    user => 'root',
    group => 'root',
    unless => "test -f /home/vagrant/php-${phpVersion}.tar.gz",
  }

  exec { 'unpack php':
    command => "tar -xf php-${phpVersion}.tar.gz",
    cwd => '/home/vagrant',
    user => 'root',
    group => 'root',
    unless => "test -d /home/vagrant/php-${phpVersion}",
    require => Exec['download php'],
  }

  exec { 'install php':
    command => "/home/vagrant/php-${phpVersion}/configure --prefix=/data/php-${phpVersionPath} --with-curl --with-gd --with-mysqli --with-pdo-mysql --enable-mbstring --with-jpeg-dir=/usr/lib --with-zlib --with-openssl --with-mcrypt --with-freetype-dir=/usr/lib --enable-zip --enable-fpm --disable-fileinfo && make && make install",
    user => 'root',
    group => 'root',
    timeout => 3600,
    unless => "test -d /data/php-${phpVersionPath}",
    require => Exec['unpack php'],
  }

  # link php binaries
  exec { 'link-php-binaries':
    command => "ln -s /data/php-${phpVersionPath}/bin/* -t .",
    cwd => '/usr/bin',
    unless => 'test -f /usr/bin/php',
    require => Exec['install php'],
  }

  # link to local file php.ini
  file { "/data/php-${phpVersionPath}/lib/php.ini":
    ensure =>file,
    source => "/vagrant/files/data/php-${phpVersionPath}/lib/php.ini",
    force => true,
    require => Exec['install php'],
    notify => Service['php-fpm'],
  }

  # link to local file php-fpm.conf
  file { "/data/php-${phpVersionPath}/etc/php-fpm.conf":
    ensure => file,
    source => "/vagrant/files/data/php-${phpVersionPath}/etc/php-fpm.conf",
    force => true,
    require => Exec['install php'],
    notify => Service['php-fpm'],
  }

  # link to local folder pool.d
  file { "/data/php-${phpVersionPath}/etc/pool.d":
    ensure => directory,
    source => "/vagrant/files/data/php-${phpVersionPath}/etc/pool.d",
    force => true,
    recurse => true,
    require => Exec['install php'],
    notify => Service['php-fpm'],
  }

  # link to local folder extensions
  file { "/data/php-${phpVersionPath}/extensions":
    ensure => directory,
    source => "/vagrant/files/data/php-${phpVersionPath}/extensions",
    force => true,
    recurse => true,
    require => Exec['install php'],
    notify => Service['php-fpm'],
  }

  # link to local file php-fpm
  file { '/etc/init.d/php-fpm':
    ensure => file,
    source => '/vagrant/files/etc/init.d/php-fpm',
    force => true,
    require => Exec['install php'],
    notify => Service['php-fpm'],
  }

  # install php-fpm as a service
  exec { 'install php-fpm as a service':
    command => 'chmod +x /etc/init.d/php-fpm && update-rc.d php-fpm defaults',
    require => [Exec['install php'], File['/etc/init.d/php-fpm']],
    notify => Service['php-fpm'],
    unless => 'service php-fpm status',
  }

  # ensure php-fpm service is up and running
  service { 'php-fpm':
    ensure => running,
    enable => true,
    hasrestart => true,
    require => [Exec['install php'], Exec['install php-fpm as a service']],
    restart => 'service php-fpm restart',
    subscribe => [File["/data/php-${phpVersionPath}/lib/php.ini"], File["/data/php-${phpVersionPath}/etc/php-fpm.conf"]],
  }
}

include prepare
include system
include nginx
include php
