module Tantot
  class Config
    include Singleton

    attr_accessor :use_after_commit_callbacks

    def initialize
      @use_after_commit_callbacks = true
    end
  end
end
