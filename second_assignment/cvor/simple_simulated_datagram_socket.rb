# frozen_string_literal: true

require 'socket'

class SimpleSimulatedDatagramSocket
  attr_reader :port
  attr_reader :loss_rate
  attr_reader :average_delay
  attr_reader :socket

  def initialize(port, loss_rate, average_delay, *args)
    @port = port
    @loss_rate = loss_rate
    @average_delay = average_delay

    @socket = UDPSocket.new(*args)
    socket.bind('0.0.0.0', port)
  end

  def send(mesg, host, port, flags = 0)
    unless rand >= loss_rate
      $logger.debug("DROPPED packet for #{host}")
      return
    end

    Thread.new do
      sleep((2 * average_delay * rand).round)
      socket.send(mesg, flags, host, port)
    end

    true
  end
end
