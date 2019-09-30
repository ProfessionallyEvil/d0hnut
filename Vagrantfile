# -*- mode: ruby -*-
# vi: set ft=ruby :

# Iterate the tools directory and build each container image housing
# one tool

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
$script = <<-SCRIPT
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
# add the vagrant user to the docker group
usermod -aG docker vagrant
apt-get install libgtk-3-0 && libx11-xcb1 && libdbus-glib-1-2
curl -o ffnightly.tar.bz2 https://download-installer.cdn.mozilla.net/pub/firefox/nightly/latest-mozilla-central/firefox-71.0a1.en-US.linux-x86_64.tar.bz2
tar -xvjf ffnightly.tar.bz2
mv firefox/ /opt/
chown vagrant:vagrant /opt/firefox/
SCRIPT
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "ubuntu/bionic64"
  config.vm.synced_folder "./", "/dohtarget"  
  # do some docker setup here
  #config.vm.provision "shell", inline: $script 
  config.vm.provision "shell", inline: <<-SHELL
  apt-get update
  SHELL
  config.vm.provision "shell", path: "cert/install.sh"
  config.vm.provision "shell", path: "dohserver/install.sh"
  config.vm.provision "shell", path: "ffnightly/install.sh"
  config.ssh.forward_x11 = true
end
