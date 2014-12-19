# -*- mode: ruby -*-
# vi: set ft=ruby :

require './Configfile'
include VagrantConfig

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  #
  config.vm.box = "ubuntu/trusty64"

  # Specify a static IP address for the machine.
  # This lets you access the Vagrant managed machine using a static, known IP.
  #
  config.vm.network "private_network", ip: "10.10.10.10"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  #
  config.vm.synced_folder SITES_PATH, "/data/www"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  #
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 512
  end

  # shell provision
  #
  #config.vm.provision :shell, :path => "scripts/puppet-upgrade.sh"

  # Enable provisioning with Puppet stand alone.  Puppet manifests
  # are contained in a directory path relative to this Vagrantfile.
  # You will need to create the manifests directory and a manifest in
  # the file default.pp in the manifests_path directory.
  #
  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.manifest_file  = "default.pp"
    puppet.module_path = "puppet/modules"
  end

  # Custom configurations
  #
  config.vm.hostname = "vm.dev"
end
