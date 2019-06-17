private_ip = my_private_ip()

if node['tensorflow']['mpi'].eql? "true"
  node.override['tensorflow']['need_mpi'] = 1
end

if node['tensorflow']['tensorrt'].eql? "true"
  node.override['tensorflow']['need_tensorrt'] = 1
end


# Only the first tensorflow server needs to create the directories in HDFS
if private_ip.eql? node['tensorflow']['default']['private_ips'][0]

   url=node['tensorflow']['hopstf_url']

   base_filename =  File.basename(url)
   cached_filename = "#{Chef::Config['file_cache_path']}/#{base_filename}"

   remote_file cached_filename do
     source url
     mode 0755
     action :create
   end

   hops_hdfs_directory cached_filename do
     action :put_as_superuser
     owner node['hops']['hdfs']['user']
     group node['hops']['group']
     mode "1755"
     dest "/user/#{node['hops']['hdfs']['user']}/#{base_filename}"
   end

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
    code <<-EOH
                set -e
                cd #{Chef::Config['file_cache_path']}
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
     code <<-EOH
                set -e
                cd #{Chef::Config['file_cache_path']}
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

bash 'extract_sparkmagic' do
  user "root"
  cwd Chef::Config['file_cache_path']
  code <<-EOF
    rm -rf #{node['conda']['dir']}/sparkmagic
    tar zxf sparkmagic-#{node['jupyter']['sparkmagic']['version']}.tar.gz
    mv sparkmagic #{node['conda']['dir']}
  EOF
end

# make sure Kerberos dev are installed
case node['platform_family']
when "debian"
  package ["libkrb5-dev", "libsasl2-dev"]
when "rhel"
  package ["krb5-devel", "krb5-workstation", "cyrus-sasl-devel"]
end

python_versions = node['kagent']['python_conda_versions'].split(',').map(&:strip)

customTf=0
if node['tensorflow']['custom_url'].start_with?("http://", "https://", "file://")
  begin
    uri = URI.parse(node['tensorflow']['custom_url'])
    %w( http https ).include?(uri.scheme)
    customTf=1
  rescue URI::BadURIError
    Chef::Log.warn "BadURIError custom_url for tensorflow: #{node['tensorflow']['custom_url']}"
    customTf=0
  rescue URI::InvalidURIError
    Chef::Log.warn "InvalidURIError custom_url for tensorflow: #{node['tensorflow']['custom_url']}"
    customTf=0
  end
end

template "#{node['conda']['base_dir']}/base-env.sh" do
  source 'base_env.sh.erb'
  owner node['conda']['user']
  group node['conda']['group']
  mode '0755'
  action :create
end

## Install GNU parallel for parallel execution
package "parallel"

py_versions = python_versions.map{ |p| p.gsub(".", "")} 
env_names = py_versions.map { |p| "python" + p }

bash "create_base_envs" do
  user node['conda']['user']
  group node['conda']['group']
  umask "022"
  environment ({ 
    'HOME' => ::Dir.home(node['conda']['user']), 
    'USER' => node['conda']['user'],
    'CONDA_DIR' => node['conda']['base_dir'],
    'MPI' => node['tensorflow']['need_mpi'],
    'HADOOP_HOME' => node['hops']['base_dir'],
    'JAVA_HOME' => node['java']['java_home'],
    'CUSTOM_TF' => customTf
   })
  code <<-EOF
    parallel --link #{node['conda']['base_dir']}/base-env.sh ::: #{env_names.join(" ")} ::: #{py_verisons.join(" ")}
  EOF
end

for python in python_versions

  if node['conda']['additional_libs'].empty? == false
    add_libs = node['conda']['additional_libs'].split(',').map(&:strip)
    for lib in add_libs
      bash "libs_py#{python}_env" do
        user node['conda']['user']
        group node['conda']['group']
        umask "022"
        environment ({ 'HOME' => ::Dir.home(node['conda']['user']),
                  'USER' => node['conda']['user'],
                  'JAVA_HOME' => node['java']['java_home'],
                  'CONDA_DIR' => node['conda']['base_dir'],
                  'HADOOP_HOME' => node['hops']['base_dir'],
                  'ENV' => envName,
                  'PY' => python.gsub('.', ''),
                  'MPI' => node['tensorflow']['need_mpi'],
                  'CUSTOM_TF' => customTf
                  })
        code <<-EOF
            yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --no-cache-dir --upgrade #{lib}
        EOF
      end
    end

  end


  if node['tensorflow']['need_tensorrt'] == 1 && node['cuda']['accept_nvidia_download_terms'] == "true" && node['platform_family'].eql?("debian")
    rt1 = python.gsub(".", "")
    if rt1 = "36"
      rt1 = "35"
    end
    # assume that is python 2.7
    rt2 = "27mu"
    if python == "3.6"
      rt2 = "35m"
    end

    bash "tensorrt_py#{python}_env" do
      user "root"
      umask "022"
      code <<-EOF
      set -e
      if [ -f /usr/local/cuda/version.txt ]  ; then
        nvidia-smi -L | grep -i gpu
        if [ $? -eq 0 ] ; then
        export CONDA_DIR=#{node['conda']['base_dir']}
        export ENV=#{envName}
        su #{node['conda']['user']} -c "cd #{tensorrt_dir}/python ; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:#{tensorrt_dir}/lib ; yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install tensorrt-#{node['cuda']['tensorrt']}"-cp#{rt1}-cp#{rt2}-linux_x86_64.whl"

        su #{node['conda']['user']} -c "cd #{tensorrt_dir}/uff ; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:#{tensorrt_dir}/lib ; yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install uff-0.2.0-py2.py3-none-any.whl"

        fi
      fi

      EOF
    end
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
