# frozen_string_literal: true

class DataPacket
  attr_reader :data
  attr_accessor :type
  attr_accessor :id
  attr_accessor :time_vector
  attr_accessor :time_scalar
  attr_accessor :reading
  attr_accessor :node

  ACK = 'ack'
  READING = 'reading'

  def self.from_json(data)
    new.from_json(data)
  end

  def self.ack(id)
    new.tap do |p|
      p.id = id
      p.type = ACK
    end
  end

  def to_s
    "#{super[0..-2]} #{to_h}>"
  end

  def to_h
    {
      type: type,
      id: id,
      node: node,
      time_vector: time_vector,
      time_scalar: time_scalar,
      reading: reading,
    }
  end

  def to_json
    to_h.to_json
  end

  def from_json(data)
    @data = JSON.parse(data)
    from_h(@data)
  end

  def from_h(data)
    @time_vector = data['time_vector']
    @time_scalar = data['time_scalar']
    @reading = data['reading']
    @node = data['node']
    @type = data['type']
    @id = data['id']
    self
  end

  def ack?
    type == ACK
  end
end
