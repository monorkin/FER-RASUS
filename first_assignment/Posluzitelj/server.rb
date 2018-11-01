require 'logger'
LOGGER = Logger.new(STDOUT)
$stdout.sync = true

LOGGER.debug('Loading server...')
require 'bundler/inline'

LOGGER.debug('Installing dependencies...')
gemfile do
  source 'https://rubygems.org'
  gem 'puma'
  gem 'rack'
  gem 'roda'
  gem 'sequel'
  gem 'sqlite3'
end

LOGGER.debug('Creating in-memory database...')
require 'sequel'
DB = Sequel.sqlite

DB.create_table :sensors do
  column :username, :string, primary_key: true
  Float :latitude, null: false
  Float :longitude, null: false
  String :ip_address, null: false
  Integer :port, null: false
end

DB.create_table :measurments do
  primary_key :id
  foreign_key(:username, :sensors, type: String, key: :username, null: false)
  String :parameter, null: false
  Float :average_value, null: false
end

LOGGER.debug('Loading application code...')
class Service
  def self.call(*args)
    new(*args).call
  end
end

class NeighbourFinder < Service
  attr_reader :sensor

  EARTH_RADIUS = 6371

  def initialize(sensor)
    @sensor = sensor.dup
  end

  def call
    DB[:sensors]
      .exclude(username: sensor[:username])
      .all
      .sort_by { |sensor| distance(sensor) }
      .last
  end

  private

  def distance(other)
    r = EARTH_RADIUS
    lat1 = sensor[:latitude]
    lat2 = other[:latitude]
    lon1 = sensor[:longitude]
    lon2 = other[:longitude]

    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a =
      Math.sin(dlat / 2)**2 +
      Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(dlon / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    r * c
  end
end

require 'roda'
class App < Roda
  plugin :json
  plugin :json_parser

  route do |r|
    r.root do
      "I'm a teapot"
    end

    r.post 'register' do
      LOGGER.info('POST /register')
      LOGGER.info("Params: #{r.params.inspect}")

      attributes = {
        username: r.params['username'],
        latitude: r.params['latitude'],
        longitude: r.params['longitude'],
        ip_address: r.params['IPaddress'],
        port: r.params['port']
      }

      begin
        sensors = DB[:sensors]
        sensors.insert(attributes)
        LOGGER.info('Success!')
        true
      rescue => e
        LOGGER.error("ERROR: #{e}")
        false
      end.to_json
    end

    r.get 'searchNeighbour' do
      LOGGER.info('GET /searchNeighbour')
      LOGGER.info("Params: #{r.params.inspect}")

      begin
        sensor =
          DB[:sensors]
          .where(username: r.params['username'])
          .first
        raise 'No sensor found' unless sensor

        LOGGER.info("SEARCHING NEIGHBOUR FOR: #{sensor.inspect}")
        neighbour = NeighbourFinder.call(sensor)
        LOGGER.info("FOUND: #{neighbour.inspect}")

        neighbour && "#{neighbour[:ip_address]}:#{neighbour[:port]}"
      rescue => e
        LOGGER.error("ERROR: #{e}")
        nil
      end.to_json
    end

    r.post 'storeMeasurments' do
      LOGGER.info('POST /storeMeasurments')
      LOGGER.info("Params: #{r.params.inspect}")

      attributes = {
        username: r.params['username'],
        parameter: r.params['parameter'],
        average_value: r.params['averageValue']
      }

      begin
        measurments = DB[:measurments]
        measurments.insert(attributes)
        LOGGER.info('Success!')
        true
      rescue => e
        LOGGER.error("ERROR: #{e}")
        false
      end.to_json
    end
  end
end

require 'socket'
ip_address = Socket.ip_address_list.find do |ai|
  ai.ipv4? && !ai.ipv4_loopback?
end.ip_address

require 'rack'
port = 80
LOGGER.info("Starting server on #{ip_address}:#{port}")
Rack::Server.start(app: App.app.freeze, Port: port)
