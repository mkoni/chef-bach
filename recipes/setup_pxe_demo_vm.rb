# Don't use proxies to talk to the bootstrap node's chef server.
Chef::Config['no_proxy'] = "#{bootstrap_fqdn},#{bootstrap_ip}"
ENV['no_proxy'] = Chef::Config['no_proxy']
log "Resetting no_proxy variables to: #{Chef::Config['no_proxy']}"

# Reminder: I can't provision external DNS on the bootstrap without knowing macs for a demo environment.  Ugly.  I guess "use a real external DNS" is gonna be a config parameter.

# vms:
# get macs
# create a virtualbox vm w/ mandated macs & pxe rom
# register in cobbler
# boot the sucker
# wait until it answers on 22
# use ssh profivisioning

# hw:
# get macs
# register in cobbler
# boot the sucker
# wait until it answers on 22
# use ssh profivisioning

# See ROM-O-MATIC.md for instruction on how to generate a new gPXE ROM.
cookbook_file pxe_rom_path do
  source 'gpxe-1.0.1-80861004.rom'
  mode 0660
end

worker_node_count = node[:bach][:cluster][:node_count].to_i
total_node_count = worker_node_count + 2

#
# We will use the vagrant driver to execute cobbler registrations on
# the bootstrap VM.
#
require 'chef/provisioning/vagrant_driver'
with_driver 'vagrant'

pxe_vms = 1.upto(total_node_count).map do |n|
  {
   :name => "bach-vm#{n}-b#{build_id}",
   :mgmt_ip => "10.0.101." + (3 + n).to_s,
   :storage_ip => "10.0.101." + (19 + n).to_s,
   :floating_ip => "10.0.101." + (35 + n).to_s,
   :netmask => '255.255.255.240',
  }
end

pxe_vms.each do |vm|
  ruby_block "#{vm[:name]}-create" do
    block do
      create_vbox_vm(name: vm[:name])
    end
  end

  machine_execute "#{vm[:name]}-cobbler-remove" do    
    machine bootstrap_fqdn
    chef_server chef_server_config_hash
    command "cobbler system remove --name=#{vm[:name]}"
    ignore_failure true
  end

  machine_execute "#{vm[:name]}-cobbler-add" do    
    machine bootstrap_fqdn
    chef_server chef_server_config_hash

    command lazy {
      mac_address = get_vbox_vm_info(name: vm[:name])
        .fetch('macaddress1').scan(/../).join(':')

      "cobbler system add --name=#{vm[:name]} " +
        "--hostname=#{fqdn_for(vm[:name])} " +
        "--profile=bcpc_host " +
        "--ip-address=#{vm[:mgmt_ip]} " +
        "--mac=#{mac_address}"
    }
  end
  
  machine_execute "#{vm[:name]}-cobbler-sync" do    
    machine bootstrap_fqdn
    chef_server chef_server_config_hash
    command 'cobbler sync'
  end
  
  ruby_block "#{vm[:name]}-boot" do
    block do
      start_vbox_vm(name: vm[:name])
    end
  end
end

# Now it's time to switch to an SSH provisioning driver.
require 'chef/provisioning/ssh_driver'
with_driver 'ssh'

# Initial setup via SSH provisioner
pxe_vms.each do |vm|
  convergence_options =
    {
     :bootstrap_proxy => Chef::Config['http_proxy'], 
     :chef_config => chef_client_config,
     :chef_version => Chef::VERSION,
     :ssl_verify_mode => :verify_none
    }
  
  transport_options =
    {
     :ip_address => vm[:mgmt_ip],
     :username => 'root',
     :ssh_options => {:password => cobbler_root_password,
                      :user_known_hosts_file => '/dev/null'}
    }
  
  machine fqdn_for(vm[:name]) do
    action [:ready, :setup, :converge]
    machine_options(:convergence_options => convergence_options,
                    :transport_options => transport_options)
    chef_server chef_server_config_hash
    chef_environment node.chef_environment  
    files cert_files_hash
    recipe 'bach_common::apt_proxy'
    recipe 'bach_common::binary_server'
    role 'Basic'
  end
end

# Re-converge the first head node with added runlist items.
machine fqdn_for("bach-vm1-b#{build_id}") do
  role 'BCPC-Hadoop-Head-Namenode-NoHA'
  role 'BCPC-Hadoop-Head-HBase'
  role 'Copylog'
end

# Re-converge the second head node with added runlist items.
machine fqdn_for("bach-vm2-b#{build_id}") do
  role 'BCPC-Hadoop-Head-Namenode-Standby'
  role 'BCPC-Hadoop-Head-MapReduce'
  role 'BCPC-Hadoop-Head-Hive'
  role 'Copylog'
end

# Skip 1 and 2, they are our head nodes.
# Reconverge workers with the complete runlist.
pxe_vms[2..-1].each do |vm|
  vm_name = fqdn_for(vm[:name]) # XXX: replace with helper!
  machine vm_name do
    role 'BCPC-Hadoop-Worker'
    role 'Copylog'
  end
end

# Re-run chef on every node by notifying machine resources.
pxe_vms.each do |vm|
  vm_name = fqdn_for(vm[:name]) # XXX: replace with helper!
  log "Re-converging #{vm_name}" do
    notifies :converge, "machine[#{vm_name}]", :immediately
  end
end
