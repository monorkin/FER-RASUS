# frozen_string_literal: true

class TimeVector
  attr_reader :name
  attr_reader :values
  attr_reader :mutex

  def initialize(name)
    @name = name
    @values = {
      name => 0
    }
    @mutex = Mutex.new
  end

  def increment
    mutex.synchronize do
      unsafe_increment
    end

    self
  end

  def update(other)
    mutex.synchronize do
      unsafe_update(other)
    end

    self
  end

  def update_and_increment(other)
    mutex.synchronize do
      unsafe_increment
      unsafe_update(other)
    end
  end

  private

  def unsafe_increment
    values[name] = values[name] + 1
  end

  def unsafe_update(other)
    other.each do |node, time|
      if (node != name)
        values[node] ||= 0
        values[node] = time if time > values[node]
      end
    end
  end
end
