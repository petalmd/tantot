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
          watch('tantot/extensions/chewy/chewy', *args)
          Tantot::Extensions::Chewy.register_watch(self, type_name, options, block)
        end
      end

      def self.register_watch(model, type_name, options, block)
        method = options.delete(:method)
        model._tantot_chewy_callbacks ||= {}
        model._tantot_chewy_callbacks[type_name] ||= []
        model._tantot_chewy_callbacks[type_name].push({method: method, options: options, block: block})
      end

      class ChewyWatcher
        include Tantot::Watcher

        def perform(changes_by_model)
          changes_by_model.each do |model, changes_by_id|
            model_watches = model._tantot_chewy_callbacks
            model_watches.each do |type_name, watch_args_array|
              # Find type
              reference =
                if type_name.is_a?(Proc)
                  if type_name.arity.zero?
                    instance_exec(&type_name)
                  else
                    type_name.call(self)
                  end
                else
                  type_name
                end

              watch_args_array.each do |watch_args|
                method = watch_args[:method]
                options = watch_args[:options]
                block = watch_args[:block]

                # Find ids to update
                backreference =
                  if (method && method.to_sym == :self) || (!method && !block)
                    # Simply extract keys from changes
                    changes_by_id.keys
                  elsif method
                    # We need to call `method`.
                    # Try to find it on the class. If so, call it once with all changes.
                    # Else, try to find it in the instance, if so, call it once per instance.
                    if model.respond_to?(method)
                      model.send(method, changes_by_id)
                    elsif model.instance_methods.include?(method)
                      ids = []
                      model.where(id: changes_by_id.keys).find_each do |instance|
                        ids |= Array.wrap(instance.send(method, changes_by_id[instance.id]))
                      end
                      ids
                    end
                  elsif block
                    ids = []
                    model.where(id: changes_by_id.keys).find_each do |instance|
                      ids |= Array.wrap(instance.instance_exec(changes_by_id[instance.id], &block))
                    end
                    ids
                  end

                if backreference
                  backreference.compact!

                  # Make sure there are any backreferences
                  if backreference.any?
                    # Call update_index, will follow normal chewy strategy
                    ::Chewy.derive_type(reference).update_index(backreference, options)
                  end
                end

              end
            end
          end
        end
      end
    end
  end
end
