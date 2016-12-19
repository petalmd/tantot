require 'ostruct'

module Tantot
  module Observe
    module Helpers
      def condition_proc(watch)
        attributes = watch.attributes
        options = watch.options
        proc do
          has_changes = attributes[:only].any? ? (self.destroyed? || (self._watch_changes.keys & attributes[:watched]).any?) : true
          has_changes && (!options.key?(:if) || self.instance_exec(&options[:if]))
        end
      end

      def update_proc(watch)
        proc do
          attributes = watch.attributes
          watched_changes =
            if attributes[:only].any?
              if self.destroyed?
                attributes[:watched].each.with_object({}) {|attr, hash| hash[attr] = [self.attributes[attr]]}
              else
                self._watch_changes.slice(*attributes[:watched])
              end
            else
              self._watch_changes
            end

          # If explicitly watching attributes, always include their values (if not already included through change tracking)
          attributes[:always].each do |attribute|
            watched_changes[attribute] = [self.attributes[attribute]] unless watched_changes.key?(attribute)
          end

          watch.agent.push(watch, self, watched_changes)
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

          # Syntax allows for the first argument to be a watcher class, shift
          # it if it is a string or class
          watcher = args.first.is_a?(String) || args.first.is_a?(Class) ? args.shift : nil

          raise ArgumentError.new("Only symbols are allowed as attribute filters") unless args.all? {|arg| arg.is_a?(Symbol)}
          raise ArgumentError.new("Only one of arguments or :only option are valid attribute filters") if args.any? && options.key?(:only)

          only_attributes = Array.wrap(options.fetch(:only, args)).collect(&:to_s)
          always_attributes = Array.wrap(options.fetch(:always, [])).collect(&:to_s)

          # Setup watch
          watch = OpenStruct.new
          watch.model = self
          watch.attributes ={
            only: only_attributes,
            always: always_attributes,
            watched: only_attributes | always_attributes
          }
          watch.options = options
          watch.block = block
          watch.watcher = watcher

          agent = Tantot.agent_registry.register(watch)

          # Setup and register callbacks
          callback_options = {}.tap do |opts|
            opts[:if] = Observe.condition_proc(watch) if watch.attributes[:only].any? || watch.options.key?(:if)
            opts[:on] = watch.options[:on] if watch.options.key?(:on)
          end
          update_proc = Observe.update_proc(watch)
          if Tantot.config.use_after_commit_callbacks
            after_commit(callback_options, &update_proc)
          else
            after_save(callback_options, &update_proc)
            after_destroy(callback_options, &update_proc)
          end

          agent
        end
      end
    end
  end
end
