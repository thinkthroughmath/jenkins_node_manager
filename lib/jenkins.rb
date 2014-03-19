require 'uri'
require 'json'
require 'open-uri'
require 'rexml/document'
require 'httparty'

HOSTNAME=ENV['JENKINS_HOSTNAME']
PORT=ENV['JENKINS_PORT']
USERNAME=ENV['JENKINS_USERNAME']
API_KEY=ENV['JENKINS_API_KEY']
MAIN_URL="http://#{HOSTNAME}:#{PORT}"
NODE_LIST_ENDPOINT = "/computer/api/json" ##endpoint to get a list of nodes
NODE_ADD_ENDPOINT = "/job/Node-add/buildWithParameters?NUM_NODES="
NODE_DELETE_ENDPOINT = "/job/Node-delete/buildWithParameters"
BUILD_QUEUE_ENDPOINT = "/queue/api/json"

class Jenkins

  # this method gets data from a specified endpoint and returns it as a string
  def self.http_get(endpoint)
    uri= URI.parse "#{MAIN_URL}#{endpoint}"
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(USERNAME, API_KEY)
    response = http.request(request)
    response.body
  end

  # this method will find the first  node name that is currently "offline" and return it.
  def self.find_available_node
    node_name=nil
    nodes = JSON.parse http_get(NODE_LIST_ENDPOINT)
    nodes["computer"].each do |i|
      if i["offline"]
        node_name=i["displayName"]
        break
      end
    end

    return node_name
  end

  def self.get_node_info
    JSON.parse( http_get(NODE_LIST_ENDPOINT) )
  end

  def self.get_node_names
    get_node_info["computer"].map{ |k,v| k['displayName'] }
  end

  def self.get_build_queue
    JSON.parse( http_get(BUILD_QUEUE_ENDPOINT) )
  end

  def self.add_nodes(num)
    puts "adding #{num} nodes"
    num.times do
      http_get("#{NODE_ADD_ENDPOINT}#{num}")
    end
  end

  def self.delete_nodes_by_name(names)
    names.each do |name|
      puts "deleting node named: #{name} "
      http_get("#{NODE_DELETE_ENDPOINT}?NODE_NAME_TO_DELETE=#{name}")
      sleep 5
    end
  end

  def self.delete_nodes(num)
    puts "deleting #{num} nodes"
    num.times do
      http_get(NODE_DELETE_ENDPOINT)
      sleep 5
    end
  end

  def self.download_client_jar
    puts "downloading slave.jar..."
    open('slave.jar', 'wb') do |file|
      file << open("#{MAIN_URL}/jnlpJars/slave.jar").read
    end
    puts "download complete"
  end

  # this method is used to get the secret key for a node on the master so that it can authenticate
  def self.get_secret(node_name)
    puts "downloading slave-agent.jnlp..."
    jnlp= http_get("/computer/#{node_name}/slave-agent.jnlp")
    doc = REXML::Document.new(jnlp)
    doc.get_text('jnlp/application-desc/argument')
  end

end