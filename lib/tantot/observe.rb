module Tantot
  module Observe
    module Helpers
      def condition_proc(attributes)
        proc do
          self.destroyed? || (self._watch_changes.keys & attributes).any?
        end
      end

      def update_proc(watcher, attributes, options)
        proc do
          watched_changes =
            if attributes.any?
              if self.destroyed?
                attributes.each.with_object({}) {|attr, hash| hash[attr] = [self[attr]]}
              else
                self._watch_changes.slice(*attributes)
              end
            else
              self._watch_changes
            end
          Tantot.collector.push(watcher, self, watched_changes, options)
        end
      end
    end

    extend Helpers

    module ActiveRecordMethods
      extend ActiveSupport::Concern

      def _watch_changes
        Tantot.config.use_after_commit_callbacks ? self.previous_changes : self.changes
      end

      class_methods do
        # watch watcher, :attr, :attr, :attr, option: :value
        def watch(watcher_name, *args)
          watcher = Tantot.derive_watcher(watcher_name)
          options = args.extract_options!
          attributes = args.collect(&:to_s)

          callback_options = {}.tap do |opts|
            # Optimize callback usage on watched attributes only
            opts[:if] = Observe.condition_proc(attributes) if args.any?
          end

          if Tantot.config.use_after_commit_callbacks
            after_commit(callback_options, &Observe.update_proc(watcher, attributes, options))
          else
            after_save(callback_options, &Observe.update_proc(watcher, attributes, options))
            after_destroy(callback_options, &Observe.update_proc(watcher, attributes, options))
          end
        end
      end
    end
  end
end
