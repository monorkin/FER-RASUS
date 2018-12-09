# frozen_string_literal: true

class Service
  def self.call(*args)
    new(*args).call
  end
end
