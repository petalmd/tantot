module Tantot
  class Registry
    include Singleton

    attr_reader :watch_config

    def initialize
      @watch_config = {}
    end
  end
end
