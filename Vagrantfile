# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "geerlingguy/centos7"
  config.vm.network "public_network", bridge: 'p1p1'
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "trac.yml"
  end
end
