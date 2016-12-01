require "tantot/version"

require 'active_support'
require 'singleton'

require "tantot/config"
require "tantot/observe"
require "tantot/strategy"

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send(:include, Tantot::Observe::ActiveRecordMethods)
end

module Tantot
  class << self

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
