require 'tantot/version'

require 'active_support'
require 'active_support/core_ext'
require 'singleton'

require 'tantot/errors'
require 'tantot/config'
require 'tantot/changes'
require 'tantot/agent'
require 'tantot/strategy'
require 'tantot/manager'
require 'tantot/observe'

require 'tantot/extensions/chewy'
require 'tantot/extensions/grape/middleware'

require 'tantot/railtie' if defined?(::Rails::Railtie)

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send(:include, Tantot::Observe::ActiveRecordMethods)
  ActiveRecord::Base.send(:include, Tantot::Extensions::Chewy)
end

module Tantot
  class << self
    attr_writer :logger

    def manager
      Thread.current[:tantot_manager] ||= Tantot::Manager.new
    end

    def config
      Tantot::Config.instance
    end

    def agent_registry
      Tantot::Agent::Registry.instance
    end

    def logger
      @logger || Rails.logger
    end

  end
end
