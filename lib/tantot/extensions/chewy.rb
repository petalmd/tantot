module Tantot
  module Extensions
    module Chewy
      extend ActiveSupport::Concern

      included do
        class_attribute :_tantot_chewy_callbacks
      end

      class_methods do
        # watch_index 'index#type', attribute, attribute, {method: [:self | :method | ignore and pass a block | ignore and don't pass a block, equivalent of :self]} [block]
        def watch_index(type_name, *args, &block)
          options = args.extract_options!
          watch_options = {}
          watch_options[:only] = options[:only] if options[:only]

          if options[:association]
            reflection = self.reflect_on_association(options[:association])
            raise ArgumentError.new("Association #{options[:association]} not found on #{self.class.name}") unless reflection
            case reflection.macro
            when :belongs_to
              watch_options[:always] = reflection.foreign_key
            when :has_one, :has_many
              if reflection.options[:through]
                if reflection.through_reflection.belongs_to?
                  watch_options[:always] = reflection.through_reflection.foreign_key
                end
              end
            else
              raise NotImplementedError.new("Association of type #{reflection.macro} not yet supported")
            end
          end

          Tantot::Extensions::Chewy.register_watch(self, type_name, options, block)
          watch('tantot/extensions/chewy/chewy', *args, watch_options)
        end
      end

      def self.register_watch(model, type_name, options, block)
        method = options.delete(:method)
        model._tantot_chewy_callbacks ||= {}
        model._tantot_chewy_callbacks[type_name] ||= []
        model._tantot_chewy_callbacks[type_name] << [method, options, block]
      end

      class ChewyWatcher
        include Tantot::Watcher

        watcher_options strategy: :chewy

        def perform(changes_by_model)
          changes_by_model.each do |model, changes_by_id|
            model_watches = model._tantot_chewy_callbacks
            model_watches.each do |type_name, watches|
              # Find type
              reference = get_chewy_type(type_name)

              backreference = watches.flat_map {|method, options, block| get_ids_to_update(model, changes_by_id, method, options, block)}.compact
              if backreference
                # Make sure there are any backreferences
                if backreference.any?
                  Tantot.logger.debug { "[Tantot] [Chewy] [update_index] #{reference} (#{backreference.count} objects): #{backreference.inspect}" }
                  ::Chewy.derive_type(reference).update_index(backreference, {})
                end
              else
                # nothing to update
              end
            end
          end
        end

        def get_chewy_type(type_name)
          if type_name.is_a?(Proc)
            if type_name.arity.zero?
              instance_exec(&type_name)
            else
              type_name.call(self)
            end
          else
            type_name
          end
        end

        def get_ids_to_update(model, changes_by_id, method, options, block)
          if options.key?(:association)
            resolve_association(model, options[:association], changes_by_id)
          else
            if (method && method.to_sym == :self) || (!method && !block)
              # Simply extract keys from changes
              changes_by_id.keys
            elsif method
              # We need to call `method`.
              # Try to find it on the class. If so, call it once with all changes.
              # There is no API to call per-instance since objects can be already destroyed
              # when using the sidekiq performer
              model.send(method, changes_by_id)
            elsif block
              # Since we can be post-destruction of the model, we can't load models here
              # Thus, the signature of the block callback is |changes| which are all
              # the changes to all the models
              model.instance_exec(changes_by_id, &block)
            end
          end
        end

        def resolve_association(model, association, changes_by_id)
          reflection = model.reflect_on_association(association)
          reflection.check_validity!
          case reflection.macro
          when :belongs_to
            changes_by_id.for_attribute(reflection.foreign_key)
          when :has_one, :has_many
            if reflection.options[:through]
              through_query =
                case reflection.through_reflection.macro
                when :belongs_to
                  reflection.through_reflection.klass.where(reflection.through_reflection.klass.primary_key => changes_by_id.for_attribute(reflection.through_reflection.foreign_key))
                when :has_many, :has_one
                  reflection.through_reflection.klass.where(reflection.through_reflection.foreign_key => changes_by_id.ids)
                end
              case reflection.source_reflection.macro
              when :belongs_to
                through_query.pluck(reflection.source_reflection.foreign_key)
              when :has_many
                reflection.source_reflection.klass.where(reflection.source_reflection.foreign_key => (through_query.ids)).ids
              end
            else
              reflection.klass.where(reflection.foreign_key => changes_by_id.ids).ids
            end
          end
        end

      end
    end
  end
end
