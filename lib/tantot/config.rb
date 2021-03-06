module Tantot
  class Config
    include Singleton

    attr_accessor :strategy, :format, :use_after_commit_callbacks, :sweep_on_push, :sidekiq_queue

    def initialize
      @strategy = :inline
      @format = :compact
      @use_after_commit_callbacks = true
      @sweep_on_push = false
      @sidekiq_queue = :default
    end
  end
end
