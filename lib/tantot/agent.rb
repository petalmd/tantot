require 'tantot/agent/base'
require 'tantot/agent/block'
require 'tantot/agent/watcher'
require 'tantot/agent/registry'

module Tantot
  module Agent

    AGENT_CLASSES = [Tantot::Agent::Block, Tantot::Agent::Watcher]

    def self.resolve!(watch)
      agent_classes = AGENT_CLASSES.collect {|klass| [klass, klass.identify(watch)]}.reject {|_klass, id| id.nil?}
      raise UnresolvableAgent("Can't resolve agent for watch: #{watch.inspect}") unless agent_classes.any?
      raise UnresolvableAgent("More than one agent manages watch: #{watch.inspect}") if agent_classes.many?
      agent_classes.first
    end

  end
end
