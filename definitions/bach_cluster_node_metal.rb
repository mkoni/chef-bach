#
# Cookbook Name:: bach-cluster
# Definition:: bach_cluster_node_metal
#
# This definition handles all the boilerplate for Vagrant-based cluster nodes.
#
# This should really be a LWRP or something.  It's cumbersome to not
# have a single resource object that caches the previously set values.
#

define :bach_cluster_node_metal do
  machine_name = params[:machine_name]
  ssh_username = params[:ssh_username] || "ubuntu1"
  ipmi_username = params[:ipmi_username] || "administrator1"
  ipmi_password = params[:ipmi_password]
  ilo_ip = params[:ilo_ip]
  mgmt_ip = params[:mgmt_ip]
  private_key = params[:private_key]
  runlist = params[:run_list]
  fqdn = fqdn_for(machine_name)
  cfg_path =  "#{Chef::Config[:file_cache_path]}/#{fqdn}.cfg"
  
  template cfg_path do
    source 'vm_configuration_metal.rb.erb'
    mode 0644
    variables({
               ssh_username: ssh_username,
               ipmi_username: ipmi_username,
               ipmi_password: ipmi_password,
               ilo_ip: ilo_ip,
               mgmt_ip: mgmt_ip,
               private_key: private_key,
              })
  end.run_action(:create)

  machine fqdn do
    add_machine_options(:vagrant_config => File.read(cfg_path))
    add_machine_options(:convergence_options => 
                        {
                         :chef_config => chef_client_config,
                         :chef_version => Chef::VERSION,
                         :ssl_verify_mode => :verify_none
                        })
    chef_server chef_server_config_hash
    chef_environment node.chef_environment  
    files cert_files_hash

    # We pass a list of items into the definition.
    # To apply those items to the resource, we have to generate method calls.
    params[:run_list].each do |item|
      raise "\"#{item}\" is not marked as a role or recipe." unless
        match_data = item.match(/^(?<type>role|recipe)\[(?<name>.+)\]$/)
      send(match_data[:type].to_s, match_data[:name])
    end

    complete(params[:complete]) if params[:complete]
    converge(params[:converge]) if params[:converge]

    action :converge_only
  end
end
