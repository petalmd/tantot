require 'tantot/version'

require 'active_support'
require 'singleton'

require 'tantot/errors'
require 'tantot/config'
require 'tantot/registry'
require 'tantot/watcher'
require 'tantot/performer'
require 'tantot/formatter'
require 'tantot/collector'
require 'tantot/observe'

require 'tantot/extensions/chewy'

require 'tantot/railtie' if defined?(::Rails::Railtie)

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send(:include, Tantot::Observe::ActiveRecordMethods)
  ActiveRecord::Base.send(:include, Tantot::Extensions::Chewy)
end

module Tantot
  class << self
    attr_writer :logger

    def derive_watcher(name)
      watcher =
        if name.is_a?(Class)
          name
        else
          class_name = "#{name.camelize}Watcher"
          watcher = class_name.safe_constantize
          raise Tantot::UnderivableWatcher, "Can not find watcher named `#{class_name}`" unless watcher
          watcher
        end
      raise Tantot::UnderivableWatcher, "Watcher class does not include Tantot::Watcher: #{watcher}" unless watcher.included_modules.include?(Tantot::Watcher)
      watcher
    end

    def collector
      Thread.current[:tantot_collector] ||= Tantot::Collector::Manager.new
    end

    def config
      Tantot::Config.instance
    end

    def registry
      Tantot::Registry.instance
    end

    def logger
      @logger || Rails.logger
    end

  end
end
