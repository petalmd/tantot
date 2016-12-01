module Tantot
  class Strategy
    class Atomic < Base
      def initialize
        @stash = {}
      end

      def perform(watch, model, id, mutations, options)
        @stash[watch] ||= {}
        @stash[watch][model] ||= {}
        @stash[watch][model][id] ||= {}
        mutations.each do |attr, changes|
          @stash[watch][model][id][attr] ||= []
          @stash[watch][model][id][attr] |= changes
        end
      end

      def leave(specific_watch = nil)
        @stash.select {|watch, _c| specific_watch.nil? || specific_watch == watch}.each do |watch, changes_per_model|
          watch.perform(changes_per_model)
        end
      end

      def clear(specific_watch = nil)
        if specific_watch.nil?
          @stash = {}
        else
          @stash.delete(specific_watch)
        end
      end
    end
  end
end
