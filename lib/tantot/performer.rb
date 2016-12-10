require 'tantot/performer/bypass'
require 'tantot/performer/inline'

begin
  require 'sidekiq'
  require 'tantot/performer/sidekiq'
rescue LoadError
  nil
end

module Tantot
  module Performer
    def self.resolve(name)
      "Tantot::Performer::#{name.to_s.camelize}".safe_constantize or raise "Can't find performer class `#{name}`"
    end
  end
end
