require 'cityhash'

module Tantot
  module Observe
    module Helpers
      def condition_proc(context)
        attributes = context[:attributes]
        options = context[:options]
        proc do
          has_changes = attributes.any? ? (self.destroyed? || (self._watch_changes.keys & attributes).any?) : true
          has_changes && (!options.key?(:if) || self.instance_exec(&options[:if]))
        end
      end

      def update_proc(context)
        proc do
          attributes = context[:attributes]
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

          Tantot.collector.push(context, self, watched_changes)
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
        # watch :attr, :attr, option: :value, &block
        # watch watcher, option: :value
        # watch option: :value, &block
        def watch(*args, &block)
          options = args.extract_options!

          watcher = args.first.is_a?(String) || args.first.is_a?(Class) ? Tantot.derive_watcher(args.shift) : nil
          unless !!watcher ^ block_given?
            raise ArgumentError.new("At least one, and only one of `watcher` or `block` can be passed")
          end

          attributes = args.collect(&:to_s)

          context = {
            model: self,
            attributes: attributes,
            options: options
          }

          if watcher
            context[:watcher] = watcher
            options.reverse_merge!(watcher.watcher_options)
          end
          context[:block_id] = CityHash.hash64(block.source_location.collect(&:to_s).join) if block_given?

          Tantot.collector.register_watch(context, block)

          callback_options = {}.tap do |opts|
            opts[:if] = Observe.condition_proc(context) if context[:attributes].any? || options.key?(:if)
            opts[:on] = options[:on] if options.key?(:on)
          end
          update_proc = Observe.update_proc(context)

          if Tantot.config.use_after_commit_callbacks
            after_commit(callback_options, &update_proc)
          else
            after_save(callback_options, &update_proc)
            after_destroy(callback_options, &update_proc)
          end
        end
      end
    end
  end
end
