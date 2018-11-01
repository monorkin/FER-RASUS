# frozen_string_literal: true

require 'socket'
require 'securerandom'
require 'net/http'
require 'singleton'
require 'csv'
require 'json'
require 'logger'

LOGGER = Logger.new(STDOUT)
$stdout.sync = true

class Reading
  ATTRIBUTES = %i[temperature pressure humidity co no2 so2].freeze

  attr_reader :data
  attr_reader :row
  attr_reader :time_alive

  attr_reader :temperature
  attr_reader :pressure
  attr_reader :humidity
  attr_reader :co
  attr_reader :no2
  attr_reader :so2

  def initialize(data, row, time_alive)
    @row = row
    @time_alive = time_alive
    @data = data || []
    @temperature = self.data[0]
    @pressure = self.data[1]
    @humidity = self.data[2]
    @co = self.data[3]
    @no2 = self.data[4]
    @so2 = self.data[5]
  end

  def inspect
    "#<#{self.class}:#{object_id} "\
    "row: #{row} "\
    "time_alive: #{time_alive} "\
    "data: #{data.inspect}>"
  end

  def to_s
    inspect
  end

  def to_json
    {
      row: row,
      time_alive: time_alive,
      data: data
    }.to_json
  end

  def |(other)
    data =
      ATTRIBUTES.map do |attr|
        (other&.send(attr) || send(attr) || 0)
      end
    self.class.new(
      data,
      row,
      time_alive
    )
  end

  def %(other)
    return dup unless other
    data =
      ATTRIBUTES.map do |attr|
        ((other&.send(attr) || 0) + (send(attr) || 0)) / 2
      end
    self.class.new(
      data,
      row,
      time_alive
    )
  end
end

class Service
  def self.call(*args)
    new(*args).call
  end
end

class ReadingGenerator < Service
  attr_reader :data_source
  attr_reader :time

  def initialize(data_source, time = nil)
    @data_source = data_source
    @time = time || Time.now
  end

  def call
    t = alive_time
    r = row(t)
    Reading.new(table[r], r, t)
  end

  private

  def table
    @table ||= CSV.read(data_source, converters: :numeric)
  end

  def row(time)
    (time % 100) + 2
  end

  def alive_time
    Time.now.to_i - time.to_i
  end
end

module HTTPClient
  DEFAULT_HEADERS = {
    'Content-Type' => 'application/json'
  }.freeze

  def ipv4_address
    Socket.ip_address_list.find do |ai|
      ai.ipv4? && !ai.ipv4_loopback?
    end.ip_address
  end

  def register(sensor)
    payload = {
      'username' => sensor.username,
      'latitude' => sensor.latitude,
      'longitude' => sensor.longitude,
      'IPaddress' => ipv4_address,
      'port' => sensor.server.port
    }.to_json

    url = "#{ENV['SERVER_HOST']}/register"
    response = Net::HTTP.post(URI(url), payload, DEFAULT_HEADERS)
    JSON.parse(response.body)
  end

  def nearest_neighbour(sensor)
    payload = {
      'username' => sensor.username
    }

    params = URI.encode_www_form(payload)
    url = "#{ENV['SERVER_HOST']}/searchNeighbour?#{params}"
    response = Net::HTTP.get(URI(url))
    JSON.parse(response)
  end

  def store_measurments(reading, sensor)
    results = Reading::ATTRIBUTES.map do |attr|
      store_measurment(attr, reading, sensor)
    end

    Reading::ATTRIBUTES.zip(results).to_h
  end

  def store_measurment(attribute, reading, sensor)
    return false unless reading.send(attribute)

    payload = {
      'username' => sensor.username,
      'parameter' => attribute,
      'averageValue' => reading.send(attribute)
    }.to_json

    url = "#{ENV['SERVER_HOST']}/storeMeasurments"
    response = Net::HTTP.post(URI(url), payload, DEFAULT_HEADERS)
    JSON.parse(response.body)
  end

  extend self
end

class SocketRegistry
  include Singleton
  attr_accessor :store

  def [](addr)
    @store ||= {}
    sock = @store[addr]
    if sock.nil? || sock&.closed?
      LOGGER.debug("Creating new socket for '#{addr}'")
      uri = URI("tcp://#{addr}")
      @store[addr] = TCPSocket.new(uri.host, uri.port)
      @store[addr]
    else
      sock
    end
  end

  def []=(addr, sock)
    @store ||= {}
    @store[addr] = sock
    sock
  end

  def register(sock)
    info = sock.addr
    addr = "#{info[-1]}:#{info[1]}"
    self[addr] = sock
  end
end

class RequestProcessor < Service
  attr_reader :socket
  attr_reader :sensor
  attr_reader :request

  def initialize(socket, sensor)
    @socket = socket
    @sensor = sensor
  end

  def call
    loop do
      @request = JSON.parse(socket.gets)

      case method
      when 'requestMeasurment' then send_reading
      when 'terminateConnection' then terminate_connection
      else log_error("unknown method '#{method}'")
      end
    end
  rescue => e
    log_error(e)
  ensure
    socket.close
  end

  protected

  def method
    request['method']
  end

  def args
    request['args']
  end

  private

  def send_reading
    reading = sensor.reading
    LOGGER.info "Generated reading #{reading} for '#{args&.first}'"
    socket.puts reading.to_json
  end

  def terminate_connection
    LOGGER.info "Terminating connection to #{socket.addr}"
    socket.close
  end

  def log_error(error)
    LOGGER.error "ERROR WHILE PROCESSING REQUEST: #{error} - #{error.class}"
  end
end

class Server
  HOST = '0.0.0.0'

  attr_reader :port
  attr_reader :sensor
  attr_reader :tcp_server
  attr_reader :thread

  def self.run(*args)
    server = new(*args)
    server.start
    server
  end

  def initialize(sensor, port = nil)
    @sensor = sensor
    @port = port || 0
  end

  def start
    @tcp_server = TCPServer.new(HOST, port)
    @port = @tcp_server.addr[1]
    @thread = Thread.new do
      loop do
        client = tcp_server.accept
        SocketRegistry.instance.register(client)
        RequestProcessor.call(client, sensor)
      end
    end
  end
end

class Sensor
  attr_accessor :longitude
  attr_accessor :latitude
  attr_accessor :data_generator
  attr_accessor :previous_readings
  attr_accessor :username
  attr_accessor :server

  def initialize(port = nil)
    @data_generator = ReadingGenerator.new('measurments.csv')
    @previous_readings = []
    @server = Server.run(self, port)
    generate_username
    generate_location
  end

  def generate_username
    @username = SecureRandom.uuid
  end

  def generate_location
    @longitude = rand(15.87..16)
    @latitude = rand(45.75..45.85)
  end

  def reading
    reading = data_generator.call
    previous_readings << reading
    previous_readings.shift if previous_readings.count > 5
    previous_readings.last
  end

  def nearest_neighbour_reading
    address = HTTPClient.nearest_neighbour(self)
    return unless address
    LOGGER.info "Requesting reading from '#{address}'..."
    socket = SocketRegistry.instance[address]
    socket.puts({ method: 'requestMeasurment', args: [username] }.to_json)
    reading = JSON.parse(socket.gets)
    Reading.new(reading['data'], reading['row'], reading['time_alive'])
  end

  def register
    HTTPClient.register(self)
  end
end

offset = rand(9) + 1
LOGGER.info "Starting main thread in #{offset}sec..."
sleep(offset)


sensor = Sensor.new(ENV['PORT']&.to_i)

loop do
  LOGGER.info "Registering sensor '#{sensor.username}' with the server..."
  sleep 1
  begin
    if sensor.register
      LOGGER.info "Sensor '#{sensor.username}' registered!"
      break
    else
      LOGGER.error "Sensor '#{sensor.username}' rejected by server."
      sensor.generate_username
      next
    end
  rescue Errno::ECONNREFUSED
    LOGGER.error 'Unable to connect to server.'
  rescue => e
    LOGGER.error "REGISTRATION FAILED: #{e} - #{e.class}"
  end
end

LOGGER.info 'Sensor listening on '\
            "#{HTTPClient.ipv4_address}:#{sensor.server.port}"

sleep_interval = (ENV['SLEEP_INTERVAL'] || 5).to_i
loop do
  own = sensor.reading
  LOGGER.info "Generated reading #{own}"

  other = sensor.nearest_neighbour_reading
  LOGGER.info "Fetched neighbour reading #{other.inspect}"

  result = (own | other) % own
  LOGGER.info "Resulting normalized reading #{result}"

  store_result = HTTPClient.store_measurments(result, sensor)
  LOGGER.info "Reading stored on the server - #{store_result}"

  sleep(sleep_interval)
end

