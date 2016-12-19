require 'tantot/watcher'

module Tantot
  module Agent
    class Watcher < Base
      def self.identify(watch)
        if watch.watcher.present?
          derive_watcher(watch.watcher)
        else
          nil
        end
      end

      def self.derive_watcher(name)
        watcher =
          if name.is_a?(Class)
            name
          else
            class_name = "#{name.camelize}Watcher"
            watcher = class_name.safe_constantize
            raise Tantot::UnderivableWatcher, "Can not find watcher named `#{class_name}`" unless watcher
            watcher
          end
        raise Tantot::UnderivableWatcher, "Watcher class does not include Tantot::Watcher: #{watcher}" unless watcher.included_modules.include?(Tantot::Watcher)
        watcher
      end

      def watcher
        # The id of the agent is the watcher class (see self#identify)
        id
      end

      def setup_watch(watch)
        watch.options.reverse_merge!(watcher.watcher_options)
      end

      def perform(changes_by_model)
        watcher.new.perform(Tantot::Changes::ByModel.new(changes_by_model))
      end

      def debug_id
        id.name
      end
    end
  end
end
