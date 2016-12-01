require 'tantot/version'

require 'active_support'
require 'singleton'

require 'tantot/errors'
require 'tantot/config'
require 'tantot/observe'
require 'tantot/strategy'
require 'tantot/watcher'

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send(:include, Tantot::Observe::ActiveRecordMethods)
end

module Tantot
  class << self

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
      raise Tantot::UnderivableWatcher, "Watcher class is does not include Tantot::Watcher: #{watcher}" unless watcher.included_modules.include?(Tantot::Watcher)
      watcher
    end

    def strategy(name = nil, &block)
      Thread.current[:tantot_strategy] ||= Tantot::Strategy.new
      if name
        Thread.current[:tantot_strategy].wrap(name, &block)
      else
        Thread.current[:tantot_strategy]
      end
    end

    def config
      Tantot::Config.instance
    end

  end
end
