require 'tantot/performer/inline'

begin
  require 'sidekiq'
  require 'tantot/performer/deferred'
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
