#!/usr/bin/env ruby

require 'json'
require File.expand_path("./../../lib/jenkins.rb", __FILE__)

MIN_NODES=ENV['MIN_NODES'].to_i
MAX_NODES=ENV['MAX_NODES'].to_i

# checks to make sure the required environment variables are set
def check_environment
  if HOSTNAME == nil || PORT == nil || USERNAME == nil || API_KEY == nil || MIN_NODES <= 0 || MAX_NODES <=0
    raise "environment variables not set. Please check that you have the following set...\
\nJENKINS_HOSTNAME\nJENKINS_PORT\nJENKINS_USERNAME\nJENKINS_API_KEY\nMIN_NODES\nMAX_NODES"
  end
  if ARGV.any?{ |s| s=~/pretend/ }
    puts "pretend flag detected"
  end

end

# Nodes that where passed in, that were not in the jenkins list of nodes should be shutdown
def clean_up_disconnected_remote_servers
  puts "Cleaning up disconnected remote servers"
  jenkins_node_names   = Jenkins.get_node_names
  puts "jenkins_node_names = #{jenkins_node_names.inspect}"
  jenkins_node_names  = jenkins_node_names.map(&:downcase)
  puts "jenkins_node_names downcased = #{jenkins_node_names.inspect}"
  other_nodes_list = ARGV[0].split ','
  puts "other_nodes_list = #{other_nodes_list.inspect}"
  nodes_to_delete = other_nodes_list.reject{|x| jenkins_node_names.include? x}
  puts "Nodes that will be deleted: #{nodes_to_delete}"
  puts "nodes_to_delete.empty? #{nodes_to_delete.empty?}"
  unless nodes_to_delete.empty?
    puts "Calling Jenkins.delete_nodes_by_name with #{nodes_to_delete.inspect}"
    Jenkins.delete_nodes_by_name nodes_to_delete 
  end
end

def scale_nodes()
  nodes = Jenkins.get_scalable_nodes
  build_queue = Jenkins.get_build_queue
  num_queued = build_queue["items"].count

  num_nodes = nodes.count
  num_busy_nodes = nodes.select {|k| !k['idle']}.count

  difference = num_nodes - num_busy_nodes
  scale_by = 0

  puts "total_nodes: #{num_nodes}"
  puts "busy_nodes: #{num_busy_nodes}"
  puts "difference #{difference}"
  puts "queued jobs: #{num_queued}"

  if num_queued > 0 and num_queued > difference
    # don't go over the max count
    scale_by = (num_nodes + num_queued) <= MAX_NODES ? num_queued : MAX_NODES - num_nodes
  else # scale down, but by how much?
    if (num_nodes - difference) >= MIN_NODES
      scale_by = -1 * difference
    else
      scale_by = -1 * ( num_nodes - MIN_NODES )
    end
  end

  if num_busy_nodes > 0 && num_queued == 0 && scale_by < 0
    puts "Not scaling down nodes while active jobs are being serviced. We were killing nodes with active threads on them"
    return
  end

  if scale_by > 0
    puts "scale up by #{scale_by}"
    Jenkins.add_nodes scale_by unless ARGV[0] =~ /pretend/
  else
    puts "scale down by #{ -1 *scale_by}"
    Jenkins.delete_nodes(-1 * scale_by) unless ARGV.any?{ |s| s=~/pretend/ }
  end
end

#### MAIN
check_environment
if ARGV.any?{ |s| s!=~/pretend/ }
  clean_up_disconnected_remote_servers
  Jenkins.remove_disconnected_nodes
end
scale_nodes
