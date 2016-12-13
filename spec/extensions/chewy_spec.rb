require "spec_helper"

if defined?(::Chewy)

  describe Tantot::Extensions::Chewy do

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
          watch_index_params << {method: :class_get_ids}
        end

        stub_model(:city) do
          class_attribute :yielded_changes

          if backreference_opt == :block
            watch_index(*watch_index_params, &block_callback)
          else
            watch_index(*watch_index_params)
          end

          def self.class_get_ids(changes)
            self.yielded_changes = changes
            [1, 2, 3]
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
          when :class_method, :block
            # Validate that the returned ids are updated
            expect(chewy_type).to receive(:update_index).with([1, 2, 3], {})
          end
        end

        # Make sure the callbacks received the changes
        if [:class_method, :block].include?(backreference_opt)
          expect(City.yielded_changes).to eq(Tantot::Changes::ById.new({city1.id => {"id" => [nil, city1.id]}, city2.id => {"id" => [nil, city2.id]}}))
        end

      end
    end

    it "should allow registering an index watch on self (all attributes, destroy)" do
      chewy_type = double

      stub_model(:city) do
        watch_index 'foo'
      end

      city = City.create!
      Tantot.collector.sweep(:bypass)

      Tantot.collector.run do
        city.destroy

        expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
        expect(chewy_type).to receive(:update_index).with([city.id], {})
      end
    end

    it "should allow registering an index watch on self (all attributes, destroy, block)" do
      chewy_type = double

      stub_model(:city) do
        watch_index 'foo' do |changes|
          changes.ids
        end
      end

      city = City.create!
      Tantot.collector.sweep(:bypass)

      Tantot.collector.run do
        city.destroy

        expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
        expect(chewy_type).to receive(:update_index).with([city.id], {})
      end
    end

    it "should allow returning nothing in a callback" do
      stub_model(:city) do
        watch_index('foo') { 1 if false }
        watch_index('bar') { [] }
        watch_index('baz') { nil }
      end

      Tantot.collector.run do
        City.create!

        expect(Chewy).not_to receive(:derive_type)
      end
    end
  end

  describe "Chewy.strategy" do
    before do
      allow(Tantot.config).to receive(:sweep_on_push).and_return(true)
    end

    it "should bypass if Chewy.strategy is :bypass" do
      stub_model(:city) do
        watch_index('foo')
      end

      expect(Chewy).not_to receive(:derive_type)
      Chewy.strategy :bypass do
        City.create!
      end
    end

    if defined?(::Sidekiq)
      context "using Sidekiq" do
        require 'sidekiq/testing'

        around do |example|
          Sidekiq::Worker.clear_all
          Tantot.config.performer = :sidekiq
          example.run
          Tantot.config.performer = :inline
        end
      end
    end

  end

end
