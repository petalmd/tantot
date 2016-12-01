module Tantot
  class Collector
    def run(&block)
      @stash = {}
      yield
    ensure
      _sweep
      @stash = nil
    end

    def push(watcher, model, id, mutations, options)
      return unless @stash
      formatter = Tantot::Formatter.resolve(watcher.watcher_options[:formatter]).new
      @stash[watcher] ||= {}
      @stash[watcher][model] ||= {}
      @stash[watcher][model][id] ||= {}
      mutations.each do |attr, changes|
        @stash[watcher][model][id][attr] ||= formatter.new_value
        @stash[watcher][model][id][attr] = formatter.run(changes, @stash[watcher][model][id][attr])
      end
    end

    def sweep(watcher = nil)
      _sweep(performer: :inline, watcher: Tantot.derive_watcher(watcher))
    end

  private

    def _sweep(options = {})
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
