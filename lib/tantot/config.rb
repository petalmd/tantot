module Tantot
  class Config
    include Singleton

    attr_accessor :performer, :use_after_commit_callbacks, :default_watcher_options, :console_mode

    def initialize
      @performer = :inline
      @use_after_commit_callbacks = true
      @default_watcher_options = {
        format: :compact
      }
      @console_mode = false
    end
  end
end
