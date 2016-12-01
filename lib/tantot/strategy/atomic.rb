module Tantot
  class Strategy
    class Atomic < Base
      def initialize
        @stash = {}
      end

      def perform(watcher, model, id, mutations, options)
        @stash[watcher] ||= {}
        @stash[watcher][model] ||= {}
        @stash[watcher][model][id] ||= {}
        mutations.each do |attr, changes|
          @stash[watcher][model][id][attr] ||= []
          @stash[watcher][model][id][attr] |= changes
        end
      end

      def leave(specific_watcher = nil)
        @stash.select {|watcher, _c| specific_watcher.nil? || specific_watcher == watcher}.each do |watcher, changes_per_model|
          watcher.new.perform(changes_per_model)
        end
      end

      def clear(specific_watcher = nil)
        if specific_watcher.nil?
          @stash = {}
        else
          @stash.delete(specific_watcher)
        end
      end
    end
  end
end
