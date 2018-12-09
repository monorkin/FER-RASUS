# frozen_string_literal: true

require 'logger'
require 'socket'
require 'json'
require 'set'

$logger = Logger.new(STDOUT)
$logger.level = if ENV['LOG_LEVEL']&.downcase == 'debug'
                  Logger::DEBUG
                else
                  Logger::INFO
                end
$stdout.sync = true

registry = Set.new

$logger.info 'Starting registry on port 4000'
socket = TCPServer.new('0.0.0.0', 4000)
client_port = 3000

$logger.debug 'Listening...'
loop do
  client = socket.accept
  request = client.gets.upcase.strip
  addr = client.peeraddr
  uri = "udp://#{addr[3]}:#{client_port}"

  $logger.debug "Received #{request} from #{uri}} - STATE #{registry}"

  if request == 'REGISTER'
    $logger.debug "Registering #{uri}"
    registry << uri
    $logger.debug "NEW STATE #{registry}"
  end

  response = (registry.to_a - Array(uri)).to_json
  $logger.debug "RESPONSE #{response}"
  client.puts response

  client.close
end
