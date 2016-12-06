module Tantot
  class Collector
    def initialize
      @stash = Hash.new do |watcher_hash, watcher|
        watcher_hash[watcher] = Hash.new do |model_hash, model|
          model_hash[model] = Hash.new do |id_hash, id|
            id_hash[id] = {}
          end
        end
      end
    end

    def run(&block)
      yield
    ensure
      sweep
    end

    def push(watcher, model, mutations, options)
      formatter = Tantot::Formatter.resolve(watcher.watcher_options[:format]).new
      attribute_hash = @stash[watcher][model.class][model.id]
      mutations.each do |attr, changes|
        attribute_hash[attr] = formatter.push(attribute_hash[attr], model, changes)
      end
      sweep_now(watcher) if Tantot.config.console_mode
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
        @stash.clear
      end
    end

  end
end
