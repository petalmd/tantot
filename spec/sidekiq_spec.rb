require "spec_helper"

if defined?(::Sidekiq)
  require 'sidekiq/testing'

  describe Tantot::Performer::Sidekiq do
    around do |example|
      Tantot.config.performer = :sidekiq
      example.run
      Tantot.config.performer = :inline
    end

    describe Tantot::Collector::Watcher do

      class SidekiqWatcher
        include Tantot::Watcher

        def perform(changes)
        end
      end

      before do
        Sidekiq::Worker.clear_all
        stub_model(:city) do
          watch SidekiqWatcher, :name
        end
      end

      it "should call a sidekiq worker" do
        Tantot.collector.run do
          City.create name: 'foo'
        end
        expect(Tantot::Performer::Sidekiq::Worker.jobs.size).to eq(1)
        expect(Tantot::Performer::Sidekiq::Worker.jobs.first["queue"]).to eq('default')
        expect(Tantot::Performer::Sidekiq::Worker.jobs.first["args"]).to eq([{
          "model" => "City",
          "attributes" => ["name"],
          "options" => {},
          "watcher" => "SidekiqWatcher",
          "collector_class" => "Tantot::Collector::Watcher"},
          {"City" => {"1" => {"name" => [nil, 'foo']}}}])
      end

      it "should call the watcher" do
        ::Sidekiq::Testing.inline! do
          Tantot.collector.run do
            city = City.create name: 'foo'
            expect_any_instance_of(SidekiqWatcher).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
          end
        end
      end

      it "should skip sidekiq and process atomically when `sweep`ing, then resume using sidekiq" do
        Sidekiq::Testing.fake! do
          Tantot.collector.run do
            # Create a model, then sweep. It should have called perform wihtout triggering a sidekiq worker
            city = City.create name: 'foo'
            expect_any_instance_of(SidekiqWatcher).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
            Tantot.collector.sweep(:inline)
            expect(Tantot::Performer::Sidekiq::Worker.jobs.size).to eq(0)

            # Further modifications should trigger through sidekiq when exiting the strategy block
            city.name = 'bar'
            city.save
          end
          expect(Tantot::Performer::Sidekiq::Worker.jobs.size).to eq(1)
          expect(Tantot::Performer::Sidekiq::Worker.jobs.first["queue"]).to eq('default')
          expect(Tantot::Performer::Sidekiq::Worker.jobs.first["args"]).to eq([{
            "model" => "City",
            "attributes" => ["name"],
            "options" => {},
            "watcher" => "SidekiqWatcher",
            "collector_class" => "Tantot::Collector::Watcher"},
            {"City" => {"1" => {"name" => ['foo', 'bar']}}}])
        end
      end
    end

    describe Tantot::Performer::Sidekiq do
      context "with a specific queue on a watcher" do
        before do
          class SidekiqWatcher
            include Tantot::Watcher

            watcher_options queue: :foo

            def perform(changes)
            end
          end

          Sidekiq::Worker.clear_all
          stub_model(:city) do
            watch SidekiqWatcher, :name
          end
        end

        it "should set the sidekiq queue accordingly" do
          Tantot.collector.run do
            City.create name: 'foo'
          end
          expect(Tantot::Performer::Sidekiq::Worker.jobs.size).to eq(1)
          expect(Tantot::Performer::Sidekiq::Worker.jobs.first["queue"]).to eq('foo')
        end
      end

      context "with a specific queue on a block" do
        before do
          Sidekiq::Worker.clear_all
          stub_model(:city) do
            watch(:name, queue: :foo) {|changes| }
          end
        end

        it "should set the sidekiq queue accordingly" do
          class SidekiqWatcher
            watcher_options queue: :foo
          end

          Tantot.collector.run do
            City.create name: 'foo'
          end
          expect(Tantot::Performer::Sidekiq::Worker.jobs.size).to eq(1)
          expect(Tantot::Performer::Sidekiq::Worker.jobs.first["queue"]).to eq('foo')
        end
      end
    end

    describe Tantot::Collector::Block do
      let(:value) { {changed: false} }
      let(:changes) { {obj: nil} }

      before do
        Sidekiq::Worker.clear_all
        v = value
        c = changes
        stub_model(:city) do
          watch(:name) {|changes| v[:changed] = true; c[:obj] = changes}
        end
      end

      it "should call a sidekiq worker" do
        Tantot.collector.run do
          City.create name: 'foo'
        end
        expect(Tantot::Performer::Sidekiq::Worker.jobs.size).to eq(1)
        block_id = Tantot.registry.watch_config.keys.last
        expect(Tantot::Performer::Sidekiq::Worker.jobs.first["queue"]).to eq('default')
        expect(Tantot::Performer::Sidekiq::Worker.jobs.first["args"]).to eq([{
          "model" => "City",
          "attributes" => ["name"],
          "options" => {},
          "block_id" => block_id,
          "collector_class" => "Tantot::Collector::Block"},
          {"1" => {"name" => [nil, 'foo']}}])
      end

      it "should call the watcher" do
        ::Sidekiq::Testing.inline! do
          city = nil
          Tantot.collector.run do
            city = City.create name: 'foo'
          end
          expect(value[:changed]).to be_truthy
          expect(changes[:obj]).to eq(Tantot::Changes::ById.new({city.id => {"name" => [nil, 'foo']}}))
        end
      end
    end

  end
end
