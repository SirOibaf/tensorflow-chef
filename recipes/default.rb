private_ip = my_private_ip()

if node['tensorflow']['mpi'].eql? "true"
  node.override['tensorflow']['need_mpi'] = 1
end

if node['tensorflow']['tensorrt'].eql? "true"
  node.override['tensorflow']['need_tensorrt'] = 1
end

# Only the first tensorflow server needs to create the directories in HDFS
if private_ip.eql? node['tensorflow']['default']['private_ips'][0]

  url=node['tensorflow']['hopstfdemo_url']

  base_filename =  "demo-#{node['tensorflow']['examples_version']}.tar.gz"
  cached_filename = "#{Chef::Config['file_cache_path']}/#{base_filename}"

  remote_file cached_filename do
    source url
    mode 0755
    action :create
  end

  # Extract Jupyter notebooks
  bash 'extract_notebooks' do
    user "root"
    cwd Chef::Config['file_cache_path']
    code <<-EOH
                set -e
                rm -rf #{node['tensorflow']['hopstfdemo_dir']}-#{node['tensorflow']['examples_version']}/#{node['tensorflow']['hopstfdemo_dir']}
                mkdir -p #{node['tensorflow']['hopstfdemo_dir']}-#{node['tensorflow']['examples_version']}/#{node['tensorflow']['hopstfdemo_dir']}
                tar -zxf #{base_filename} -C #{Chef::Config['file_cache_path']}/#{node['tensorflow']['hopstfdemo_dir']}-#{node['tensorflow']['examples_version']}/#{node['tensorflow']['hopstfdemo_dir']}
                chown -RL #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{Chef::Config['file_cache_path']}/#{node['tensorflow']['hopstfdemo_dir']}-#{node['tensorflow']['examples_version']}
        EOH
  end

  hops_hdfs_directory "/user/#{node['hops']['hdfs']['user']}/#{node['tensorflow']['hopstfdemo_dir']}" do
    action :create_as_superuser
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "1775"
  end

  hops_hdfs_directory "#{Chef::Config['file_cache_path']}/#{node['tensorflow']['hopstfdemo_dir']}-#{node['tensorflow']['examples_version']}/#{node['tensorflow']['hopstfdemo_dir']}" do
    action :replace_as_superuser
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "1755"
    dest "/user/#{node['hops']['hdfs']['user']}/#{node['tensorflow']['hopstfdemo_dir']}"
  end

  # Feature store tour artifacts
   url=node['featurestore']['hops_featurestore_demo_url']

   base_filename =  "demo-featurestore-#{node['featurestore']['examples_version']}.tar.gz"
   cached_filename = "#{Chef::Config['file_cache_path']}/#{base_filename}"

   remote_file cached_filename do
     source url
     mode 0755
     action :create
   end

  # Extract Feature Store Jupyter notebooks
   bash 'extract_notebooks' do
     user "root"
     cwd Chef::Config['file_cache_path']
     code <<-EOH
                set -e
                rm -rf #{node['featurestore']['hops_featurestore_demo_dir']}-#{node['featurestore']['examples_version']}/#{node['featurestore']['hops_featurestore_demo_dir']}
                mkdir -p #{node['featurestore']['hops_featurestore_demo_dir']}-#{node['featurestore']['examples_version']}/#{node['featurestore']['hops_featurestore_demo_dir']}
                tar -zxf #{base_filename} -C #{Chef::Config['file_cache_path']}/#{node['featurestore']['hops_featurestore_demo_dir']}-#{node['featurestore']['examples_version']}/#{node['featurestore']['hops_featurestore_demo_dir']}
                chown -RL #{node['hops']['hdfs']['user']}:#{node['hops']['group']} #{Chef::Config['file_cache_path']}/#{node['featurestore']['hops_featurestore_demo_dir']}-#{node['featurestore']['examples_version']}
     EOH
   end

   hops_hdfs_directory "/user/#{node['hops']['hdfs']['user']}/#{node['featurestore']['hops_featurestore_demo_dir']}" do
     action :create_as_superuser
     owner node['hops']['hdfs']['user']
     group node['hops']['group']
     mode "1775"
   end

   hops_hdfs_directory "#{Chef::Config['file_cache_path']}/#{node['featurestore']['hops_featurestore_demo_dir']}-#{node['featurestore']['examples_version']}/#{node['featurestore']['hops_featurestore_demo_dir']}" do
     action :replace_as_superuser
     owner node['hops']['hdfs']['user']
     group node['hops']['group']
     mode "1755"
     dest "/user/#{node['hops']['hdfs']['user']}/#{node['featurestore']['hops_featurestore_demo_dir']}"
   end

end

if node['tensorflow']['need_tensorrt'] == 1 && node['cuda']['accept_nvidia_download_terms'] == "true"

  case node['platform_family']
  when "debian"

    cached_file="#{Chef::Config['file_cache_path']}/#{node['cuda']['tensorrt_version']}"
    remote_file cached_file do
      source "#{node['download_url']}/#{node['cuda']['tensorrt_version']}"
      mode 0755
      action :create
      retries 1
      not_if { File.exist?(cached_file) }
    end

    tensorrt_dir="#{node['tensorflow']['dir']}/TensorRT-#{node['cuda']['tensorrt']}"
    bash "install-tensorrt-ubuntu" do
      user "root"
      code <<-EOF
       set -e
       cd #{Chef::Config['file_cache_path']}
       tar zxf #{cached_file}
       mv TensorRT-#{node['cuda']['tensorrt']} #{node['tensorflow']['dir']}
    EOF
      not_if "test -d #{tensorrt_dir}"
    end

    magic_shell_environment 'LD_LIBRARY_PATH' do
      value "$LD_LIBRARY_PATH:#{tensorrt_dir}/lib"
    end
  end
end

# make sure Kerberos dev are installed
case node['platform_family']
when "debian"
  package ["libkrb5-dev", "libsasl2-dev"]
when "rhel"
  package ["krb5-devel", "krb5-workstation", "cyrus-sasl-devel"]
end

python_versions = node['kagent']['python_conda_versions'].split(',').map(&:strip)

for python in python_versions

  envName = "python" + python.gsub(".", "")

  remote_file "/tmp/chef-solo/#{envName}.tar.gz" do
    source "http://snurran.sics.se/hops/base_envs/#{envName}.tar.gz" 
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  # TODO(Fabio): call conda-unpack
  bash "extrac_base_envs" do 
    user "root"
    group "root" 
    code <<-EOF
      set -e
      mkdir /srv/hops/anaconda/envs/#{envName}
      mv /tmp/chef-solo/#{envName}.tar.gz /srv/hops/anaconda/envs/#{envName}
      cd /srv/hops/anaconda/envs/#{envName}
      tar xf #{envName}.tar.gz
      rm #{envName}.tar.gz
      chown -R anaconda:anaconda /srv/hops/anaconda/envs/#{envName}
    EOF
  end
  
end

#
# Need to synchronize conda environments for newly joined or rejoining nodes.
#
package "rsync"

#
# Allow hopsworks/user to ssh into servers with the anaconda user to make a copy of environments.
#
homedir = node['conda']['user'].eql?("root") ? "/root" : "/home/#{node['conda']['user']}"
kagent_keys "#{homedir}" do
  cb_user "#{node['conda']['user']}"
  cb_group "#{node['conda']['group']}"
  cb_name "hopsworks"
  cb_recipe "default"
  action :get_publickey
end