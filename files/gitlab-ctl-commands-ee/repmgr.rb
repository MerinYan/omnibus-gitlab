require "#{base_path}/embedded/service/omnibus-ctl-ee/lib/repmgr"
require "#{base_path}/embedded/service/omnibus-ctl/lib/gitlab_ctl"

add_command_under_category('repmgr', 'database', 'Manage repmgr PostgreSQL cluster nodes', 2) do |_cmd_name, _args|
  repmgr_command = ARGV[3]
  repmgr_subcommand = ARGV[4]
  repmgr_primary = ARGV[5]
  begin
    node_attributes = GitlabCtl::Util.get_public_node_attributes
  rescue GitlabCtl::Errors::NodeError => e
    log e.message
  end
  # We only need the arguments if we're performing an action which needs to
  # know the primary node
  repmgr_options = repmgr_parse_options

  repmgr_args = begin
                  {
                    primary: repmgr_primary,
                    user: repmgr_options[:user] || node_attributes['repmgr']['user'],
                    database:  node_attributes['repmgr']['database'],
                    directory: node_attributes['gitlab']['postgresql']['data_dir'],
                    verbose: repmgr_options[:verbose],
                    wait: repmgr_options[:wait],
                    host: repmgr_options[:host],
                    node: repmgr_options[:node]
                  }
                rescue NoMethodError
                  $stderr.puts "Unable to determine node attributes. Has reconfigure successfully ran?"
                  exit 1
                end
  begin
    repmgr_obj = Repmgr.new(repmgr_command, repmgr_subcommand, repmgr_args)
    results = repmgr_obj.execute
  rescue Mixlib::ShellOut::ShellCommandFailed
    exit 1
  rescue NoMethodError
    if repmgr_command
      $stderr.puts "The repmgr command #{repmgr_command} does not support #{repmgr_subcommand}"
    end
    puts repmgr_help
    exit 1
  rescue NameError => ne
    puts ne
    $stderr.puts "There is no repmgr command #{repmgr_command}"
    puts repmgr_help
    exit 1
  end
  log results
end

add_command_under_category('repmgr-check-master', 'database', 'Check if the current node is the repmgr master', 2) do
  node = Repmgr::Node.new
  begin
    if node.is_master?
      Kernel.exit 0
    else
      Kernel.exit 2
    end
  rescue Repmgr::MasterError => se
    $stderr.puts "Error checking for master: #{se}"
    Kernel.exit 3
  end
end

add_command_under_category('repmgr-event-handler', 'database', 'Handle events from rpmgrd actions', 2) do
  Repmgr::Events.fire(ARGV)
end

def repmgr_help
  <<-EOF
  Available repmgr commands:
  master register -- Register the current node as a master node in the repmgr cluster
  standby
    clone MASTER -- Clone the data from node MASTER to set this node up as a standby server
    register -- Register the node as a standby node in the cluster. Assumes clone has been done
    setup MASTER -- Performs all steps necessary to setup the current node as a standby for MASTER
    follow MASTER -- Follow the new master node MASTER
    unregister --node=X -- Removes the node with id X from the cluster. Without --node removes the current node.
    promote -- Promote the current node to be the master node
  cluster show -- Displays the current membership status of the cluster
  EOF
end

def repmgr_parse_options
  options = {
    node: nil,
    wait: true,
    verbose: ''
  }

  OptionParser.new do |opts|
    opts.on('-w', '--no-wait', 'Do not wait before starting the setup process') do
      options[:wait] = false
    end

    opts.on('-v', '--verbose', 'Run repmgr with verbose option') do
      options[:verbose] = '-v'
    end

    opts.on('-n', '--node NUMBER', 'The node number to operate on') do |n|
      options[:node] = n
    end

    opts.on('--host HOSTNAME', 'The host name to operate on') do |h|
      options[:host] = h
    end

    opts.on('--user USER', 'The database user to connect as') do |u|
      options[:user] = u
    end
  end.parse!(ARGV)

  options
end
