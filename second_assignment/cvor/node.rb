# frozen_string_literal: true

require_relative './emulated_system_clock'
require_relative './simple_simulated_datagram_socket'
require_relative './time_vector'
require_relative './data_packet'
require_relative './service'
require_relative './reading_generator'
require_relative './packet_sender'

require 'set'
require 'socket'
require 'securerandom'
require 'json'
require 'logger'
require 'csv'
require 'uri'

$logger = Logger.new(STDOUT)
$logger.level = if ENV['LOG_LEVEL']&.downcase == 'debug'
                  Logger::DEBUG
                else
                  Logger::INFO
                end
$stdout.sync = true

class Node
  attr_reader :scalar_clock
  attr_reader :vector_clock
  attr_reader :aggregator
  attr_reader :generator
  attr_reader :server
  attr_reader :ack_wait_list
  attr_reader :packet_sender
  attr_reader :socket

  def initialize
    @scalar_clock = EmulatedSystemClock.new
    @vector_clock = TimeVector.new(ipv4_address)
    @ack_wait_list = Set.new
    @socket = build_socket
    @packet_sender = PacketSender.new(socket, ack_wait_list)
    packet_sender.start!
    @aggregator = nil
    @generator = nil
    @server = nil
  end

  def call
    @aggregator = Node::Aggregator.new(self)
    @generator = Node::Generator.new(self)
    @server = Node::Server.new(self)

    [
      Thread.new { aggregator.call },
      Thread.new { generator.call },
      Thread.new { server.call }
    ].map(&:join)
  end

  def ipv4_address
    Socket.ip_address_list.find do |ai|
      ai.ipv4? && !ai.ipv4_loopback?
    end.ip_address
  end

  private

  def build_socket
    port = ENV['PORT']&.to_i
    loss_rate = ENV['LOSS_RATE']&.to_f || 0
    average_delay = ENV['AVERAGE_DELAY']&.to_i || 0

    $logger.debug("SOCKET - PORT: #{port} LOSS_RATE: #{loss_rate} AVERAGE_DELAY: #{average_delay}")

    SimpleSimulatedDatagramSocket.new(port, loss_rate, average_delay)
  end
end

class Node::Aggregator
  attr_reader :node
  attr_reader :bucket
  attr_reader :mutex

  def initialize(node)
    @node = node
    @bucket = []
    @mutex = Mutex.new
  end

  def call
    loop do
      sleep(5)
      mutex.synchronize do
        sanitize_bucket!
        $logger.info(
          "\n"\
          "NODE: #{node.vector_clock.name}\n"\
          "AVERAGE: #{average_value}\n"\
          "VECTOR_SORTED: \n\t#{vector_sorted_bucket.join("\n\t")}\n"\
          "SCALAR_SORTED: \n\t#{scalar_sorted_bucket.join("\n\t")}"
        )
        empty_bucket!
      end
    end
  end

  def <<(data)
    add_packet(data)
  end

  def add_packet(data)
    packet = data.is_a?(DataPacket) ? data : DataPacket.new(data)
    mutex.synchronize { bucket << packet }
  end

  private

  def vector_sorted_bucket
    bucket.sort_by { |packet| packet.time_vector[node.vector_clock.name] || 0 }
  end

  def scalar_sorted_bucket
    bucket.sort_by { |packet| packet.time_scalar }
  end

  def average_value
    (bucket.map(&:reading).compact.sum&.to_f || 0) / bucket.count.to_f
  end

  def sanitize_bucket!
    bucket.compact!
    bucket.uniq!
  end

  def empty_bucket!
    @bucket = []
  end
end

class Node::Generator
  attr_reader :node
  attr_reader :generator

  def initialize(node)
    @node = node
    @generator = ReadingGenerator.new('measurments.csv', node.scalar_clock)
  end

  def call
    loop do
      sleep(1)
      broadcast_reading(generator.call)
    end
  end

  def broadcast_reading(reading)
    packet = build_packet(reading)

    node.aggregator.add_packet(packet)

    nodes.each do |node|
      $logger.debug("Broadcasting #{packet} to #{node}")

      uri = URI(node)
      self.node.packet_sender.send(packet, uri.host, self.node.socket.port)
    end
  end

  def nodes
    s = TCPSocket.new('registry', 4000)
    s.puts 'LIST'
    JSON.parse(s.gets)
  end

  def build_packet(reading)
    DataPacket.new.tap do |p|
      p.id = SecureRandom.uuid
      p.type = 'reading'
      p.time_vector = node.vector_clock.increment.values
      p.time_scalar = node.scalar_clock.current_time_millis
      p.reading = reading
      p.node = node.ipv4_address
    end
  end
end

class Node::Server
  attr_reader :node
  attr_reader :socket
  attr_reader :raw_socket

  def initialize(node)
    @node = node
    @socket = node.socket
    @raw_socket = socket.socket
  end

  def call
    loop do
      len = raw_socket.recv(8, Socket::MSG_PEEK).unpack('Q').first
      data, sender = raw_socket.recvfrom(len + 8)
      packet = DataPacket.from_json(data.unpack('QA*').last)

      if packet.ack?
        ack_packet(packet.id)
      else
        process_packet(packet)
        send_ack(packet.id, sender[3], sender[1])
      end
    end
  end

  def ack_packet(id)
    $logger.debug("Received ACK for #{id}")
    node.ack_wait_list.delete(id)
  end

  def process_packet(packet)
    node.vector_clock.update_and_increment(packet.time_vector)
    node.aggregator.add_packet(packet)
  end

  def send_ack(id, host, port)
    packet = DataPacket.ack(id)
    node.packet_sender.send_ack(packet, host, port)
  end
end

$logger.debug('Giving the registry a chance to start')
sleep(5)

$logger.debug('Registering node')
s = TCPSocket.new('registry', 4000)
s.puts 'REGISTER'

$logger.info('Starting random sleep')
sleep(rand(1..10))
$logger.info('Starting')

node = Node.new
node.call
