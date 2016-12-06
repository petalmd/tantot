module Tantot
  module Extensions
    module Chewy
      extend ActiveSupport::Concern

      class_methods do
        # watch_index 'index#type', attribute, attribute, {method: [:self | :method | ignore and pass a block]} [block]
        def watch_index(type_name, *args, &block)
          options = args.extract_options!
          watch('tantot/extensions/chewy/chewy', *args)
          Tantot::Extensions::Chewy::ChewyWatcher.register_watch(self, type_name, options, block)
        end
      end

      class ChewyWatcher
        include Tantot::Watcher

        class_attribute :callbacks

        # Used in tests
        def self.clear_callbacks
          self.callbacks = {}
        end

        def self.register_watch(model, type_name, options, block)
          method = options.delete(:method)
          self.callbacks ||= {}
          self.callbacks[model] ||= {}
          self.callbacks[model][type_name] ||= []
          self.callbacks[model][type_name].push({method: method, options: options, block: block})
        end

        def perform(changes_by_model)
          changes_by_model.each do |model, changes_by_id|
            model_watches = callbacks[model]
            model_watches.each do |type_name, watch_args_array|
              watch_args_array.each do |watch_args|
                method = watch_args[:method]
                options = watch_args[:options]
                block = watch_args[:block]
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
                # Find ids to update
                backreference =
                  if method && method.to_sym == :self
                    # Simply extract keys from changes
                    changes_by_id.keys
                  elsif method
                    # We need to call `method`. Chewy calls it per-instance. We
                    # call it on the class, and pass the change hash
                    model.send(method, changes_by_id)
                  else
                    model.class_eval(&block)
                  end

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
