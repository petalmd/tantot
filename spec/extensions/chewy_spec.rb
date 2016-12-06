require "spec_helper"

describe Tantot::Extensions::Chewy do

  # Stub the Chewy namespace
  before do
    stub_const("Chewy", {})
  end

  [nil, :self, :class_method, :block, :instance_method].product([:some, :all]).each do |backreference_opt, attribute_opt|
    it "should update indexes using backreference: #{backreference_opt.inspect}, attributes: #{attribute_opt}" do
      chewy_type = double

      watch_index_params = ['foo']
      watch_index_params << :id if attribute_opt == :some

      block_callback = proc do |changes|
        self.class.yielded_changes ||= []
        self.class.yielded_changes.push(changes)
        # Intentionally return a scalar, it is the extension's job to wrap in an array
        self.id + 1
      end


      case backreference_opt
      when nil, :block
      when :self
        watch_index_params << {method: :self}
      when :class_method
        watch_index_params << {method: :class_get_ids}
      when :instance_method
        watch_index_params << {method: :instance_get_ids}
      end

      stub_model(:city) do
        class_attribute :yielded_changes

        if [:block, :block_instance].include?(backreference_opt)
          watch_index(*watch_index_params, &block_callback)
        else
          watch_index(*watch_index_params)
        end

        def self.class_get_ids(changes)
          self.yielded_changes = changes
          [1, 2, 3]
        end

        def instance_get_ids(changes)
          self.class.yielded_changes ||= []
          self.class.yielded_changes.push(changes)
          [self.id + 1]
        end
      end

      city1 = city2 = nil

      Tantot.collector.run do
        city1 = City.create!
        city2 = City.create!

        # Stub the integration point between us and Chewy
        expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)

        # Depending on backreference
        case backreference_opt
        when nil, :self
          # Implicit and self reference will update with the created model id
          expect(chewy_type).to receive(:update_index).with([city1.id, city2.id], {})
        when :class_method
          # Validate that the returned ids are updated
          expect(chewy_type).to receive(:update_index).with([1, 2, 3], {})
        when :instance_method, :block
          # Validate that the returned ids are updated (we increment to differ from the self reference)
          expect(chewy_type).to receive(:update_index).with([city1.id + 1, city2.id + 1], {})
        end
      end

      # Make sure the callbacks received the changes
      case backreference_opt
      when :class_method
        expect(City.yielded_changes).to eq({city1.id => {"id" => [nil, city1.id]}, city2.id => {"id" => [nil, city2.id]}})
      when :block, :instance_method
        expect(City.yielded_changes).to eq([{"id" => [nil, city1.id]}, {"id" => [nil, city2.id]}])
      end

    end
  end

  it "should allow registering an index watch on self (all attributes, destroy)" do
    chewy_type = double

    stub_model(:city) do
      watch_index 'foo', method: :self
    end

    city = City.create!
    Tantot.collector.sweep(performer: :bypass)

    Tantot.collector.run do
      city.destroy

      expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
      expect(chewy_type).to receive(:update_index).with([city.id], {})
    end
  end
end
