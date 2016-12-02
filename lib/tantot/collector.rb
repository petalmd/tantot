module Tantot
  class Collector
    def initialize
      @stash = {}
    end

    def run(&block)
      yield
    ensure
      sweep
    end

    def push(watcher, model, mutations, options)
      formatter = Tantot::Formatter.resolve(watcher.watcher_options[:formatter]).new
      @stash[watcher] ||= {}
      @stash[watcher][model.class] ||= {}
      @stash[watcher][model.class][model.id] ||= {}
      mutations.each do |attr, changes|
        @stash[watcher][model.class][model.id][attr] ||= formatter.new_value
        @stash[watcher][model.class][model.id][attr] = formatter.run(model, changes, @stash[watcher][model.class][model.id][attr])
      end
    end

    def sweep_now(watcher = nil)
      sweep(performer: :inline, watcher: Tantot.derive_watcher(watcher))
    end

    def sweep(options = {})
      filtered_stash = options[:watcher] ? @stash.select {|watcher, _c| options[:watcher] == watcher} : @stash
      filtered_stash.each do |watcher, changes_per_model|
        performer = Tantot::Performer.resolve(options[:performer] || Tantot.config.performer).new
        performer.run(watcher, changes_per_model)
      end
      if options[:watcher]
        @stash.delete(options[:watcher])
      else
        @stash = {}
      end
    end

  end
end
