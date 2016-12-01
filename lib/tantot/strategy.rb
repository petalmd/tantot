require 'tantot/strategy/base'
require 'tantot/strategy/bypass'
require 'tantot/strategy/atomic'

begin
  require 'sidekiq'
  require 'tantot/strategy/sidekiq'
rescue LoadError
  nil
end

module Tantot
  class Strategy
    def initialize
      @strategy = Tantot::Strategy::Bypass.new
    end

    def current
      @strategy
    end

    def wrap(name)
      @strategy = resolve(name).new
      yield
    ensure
      @strategy.leave
      @strategy = Tantot::Strategy::Bypass.new
    end

    def join(watcher)
      raise ArgumentError.new("`join` must be called with a watcher class including Tantot::Watcher") unless watcher.included_modules.include?(Tantot::Watcher)
      @strategy.leave(watcher)
      @strategy.clear(watcher)
    end

  private

    def resolve(name)
      "Tantot::Strategy::#{name.to_s.camelize}".safe_constantize or raise "Can't find strategy class `#{name}`"
    end
  end
end
