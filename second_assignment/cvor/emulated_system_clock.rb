# frozen_string_literal: true

class EmulatedSystemClock
  attr_reader :start_time
  attr_reader :jitter

  def initialize
    @start_time = Time.now
    @jitter = rand(-20..20) / 100.0
  end

  def current_time_millis
    coef = (start_time - Time.now).to_i
    diff = (coef * 1000).to_i
    (start_time.to_f * 1000).to_i + (diff * ((1 + jitter) ** coef)).to_i
  end
end
