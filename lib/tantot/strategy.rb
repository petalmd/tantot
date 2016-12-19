require 'tantot/strategy/bypass'
require 'tantot/strategy/inline'

begin
  require 'chewy'
  require 'tantot/strategy/chewy'
rescue LoadError
  nil
end

begin
  require 'sidekiq'
  require 'tantot/strategy/sidekiq'
rescue LoadError
  nil
end

module Tantot
  module Strategy
    def self.resolve(name)
      "Tantot::Strategy::#{name.to_s.camelize}".safe_constantize or raise "Can't find strategy class `#{name}`"
    end
  end
end
