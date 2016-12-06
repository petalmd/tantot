require "spec_helper"

describe Tantot::Extensions::Chewy do

  # Stub the Chewy namespace
  before do
    stub_const("Chewy", {})
  end

  [nil, :self, :class_method, :block].product([:some, :all]).each do |backreference_opt, attribute_opt|
    it "should update indexes using backreference: #{backreference_opt.inspect}, attributes: #{attribute_opt}" do
      chewy_type = double

      watch_index_params = ['foo']
      watch_index_params << :id if attribute_opt == :some

      block_callback = proc do |changes|
        self.yielded_changes = changes
        [1, 2, 3]
      end

      case backreference_opt
      when nil, :block
      when :self
        watch_index_params << {method: :self}
      when :class_method
        watch_index_params << {method: :get_ids}
      end

      stub_model(:city) do
        class_attribute :yielded_changes
        if backreference_opt == :block
          watch_index(*watch_index_params, &block_callback)
        else
          watch_index(*watch_index_params)
        end
        def self.get_ids(changes)
          self.yielded_changes = changes
          [1, 2, 3]
        end
      end

      city = nil

      Tantot.collector.run do
        city = City.create!

        # Stub the integration point between us and Chewy
        expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)

        # Depending on backreference
        case backreference_opt
        when nil, :self
          # Implicit and self reference will update with the created model id
          expect(chewy_type).to receive(:update_index).with([city.id], {})
        when :class_method, :block
          # Validate that the returned ids are updated
          expect(chewy_type).to receive(:update_index).with([1, 2, 3], {})
        end
      end

      # Make sure the callbacks received the changes
      if [:class_method, :block].include?(backreference_opt)
        expect(City.yielded_changes).to eq({city.id => {"id" => [nil, city.id]}})
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
