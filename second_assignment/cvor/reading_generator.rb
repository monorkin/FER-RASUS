# frozen_string_literal: true

require_relative './service'

class ReadingGenerator < Service
  attr_reader :data_source
  attr_reader :clock

  def initialize(data_source, clock)
    @data_source = data_source
    @clock = clock
  end

  def call
    t = clock.current_time_millis / 1000
    r = row(t)
    (table[r] || [])[3]
  end

  private

  def table
    @table ||= CSV.read(data_source, converters: :numeric)
  end

  def row(time)
    (time % 100) + 2
  end
end
