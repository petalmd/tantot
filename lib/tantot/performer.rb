require 'tantot/performer/bypass'
require 'tantot/performer/inline'

begin
  require 'sidekiq'
  require 'tantot/performer/sidekiq'
rescue LoadError
  nil
end

module Tantot
  module Performer
    def self.resolve(name)
      "Tantot::Performer::#{name.to_s.camelize}".safe_constantize or raise "Can't find performer class `#{name}`"
    end

    # Convert class to class names
    def self.marshal(changes_per_model)
      changes_per_model.each.with_object({}) {|(model_class, changes), hash| hash[model_class.name] = changes}
    end

    # Convert back from class names to classes, and object ids to integers
    def self.unmarshal(changes_per_model)
      changes_per_model.each.with_object({}) do |(model_class_name, changes_by_id), model_hash|
        model_hash[model_class_name.constantize] = changes_by_id.each.with_object({}) do |(id, changes), change_hash|
          change_hash[id.to_i] = changes
        end
      end
    end
  end
end
