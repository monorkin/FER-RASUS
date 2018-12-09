# frozen_string_literal: true

class PacketSender
  attr_reader :socket
  attr_reader :queue
  attr_reader :ack_wait_list
  attr_reader :worker
  attr_reader :timeout

  def initialize(socket, ack_wait_list, timeout = nil)
    @socket = socket
    @queue = Queue.new
    @ack_wait_list = ack_wait_list
    @worker = nil
    @timeout = timeout || ENV['TIMEOUT']&.to_i || 3
  end

  def start!
    $logger.debug("PACKET SENDER - TIMEOUT: #{timeout}")
    @worker = Thread.new { work! }
  end

  def send(packet, host, port, flags = 0)
    queue << [packet, host, port, flags]
    true
  end

  def send_ack(packet, host, port, flags = 0)
    $logger.debug("Sending ACK #{packet} to #{host}")
    socket.send(format_packet(packet), host, port, flags)
    true
  end

  def work!
    loop do
      packet, host, port, flags = queue.pop
      spawn_job(packet, host, port, flags)
    end
  end

  private

  def spawn_job(packet, host, port, flags)
    Thread.new do
      retransmission = false
      loop do
        $logger.debug("#{retransmission ? 'RETRY' : ''} Sending #{packet} to #{host}")

        ack_wait_list << packet.id
        socket.send(format_packet(packet), host, port, flags)
        sleep(timeout)

        unless ack_wait_list.include?(packet.id)
          $logger.debug("Breaking send-loop for packet #{packet.id} - ACK RECEIVED")
          break
        end

        retransmission = true
      end
    end
  end

  def format_packet(packet)
    payload = packet.to_json
    [payload.bytesize, payload].pack('QA*')
  end
end
