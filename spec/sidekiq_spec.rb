require "spec_helper"

if defined?(::Sidekiq)
  require 'sidekiq/testing'

  describe Tantot::Performer::Deferred do
    around do |example|
      Tantot.config.performer = :deferred
      example.run
      Tantot.config.performer = :inline
    end

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
      expect(Tantot::Performer::Deferred::Worker.jobs.size).to eq(1)
      expect(Tantot::Performer::Deferred::Worker.jobs.first["args"]).to eq(["SidekiqWatcher", {"City" => {"1" => {"name" => [nil, 'foo']}}}])
    end

    it "should call the watcher" do
      ::Sidekiq::Testing.inline! do
        Tantot.collector.run do
          city = City.create name: 'foo'
          expect_any_instance_of(SidekiqWatcher).to receive(:perform).with({City => {city.id => {"name" => [nil, 'foo']}}})
        end
      end
    end

    it "should skip sidekiq and process atomically when `sweep`ing, then resume using sidekiq" do
      Sidekiq::Testing.fake! do
        Tantot.collector.run do
          # Create a model, then sweep. It should have called perform wihtout triggering a sidekiq worker
          city = City.create name: 'foo'
          expect_any_instance_of(SidekiqWatcher).to receive(:perform).with({City => {city.id => {"name" => [nil, 'foo']}}})
          Tantot.collector.sweep(SidekiqWatcher)
          expect(Tantot::Performer::Deferred::Worker.jobs.size).to eq(0)

          # Further modifications should trigger through sidekiq when exiting the strategy block
          city.name = 'bar'
          city.save
        end
        expect(Tantot::Performer::Deferred::Worker.jobs.size).to eq(1)
        expect(Tantot::Performer::Deferred::Worker.jobs.first["args"]).to eq(["SidekiqWatcher", {"City" => {"1" => {"name" => ['foo', 'bar']}}}])
      end
    end
  end
end
