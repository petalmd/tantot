require "spec_helper"

if defined?(::Sidekiq)
  require 'sidekiq/testing'

  describe Tantot::Strategy::Sidekiq do
    class SidekiqWatcher
      def perform(changes)
      end
    end

    before do
      stub_model(:city) do
        watch SidekiqWatcher, :name
      end
    end

    it "should call a sidekiq worker" do
      ::Sidekiq::Testing.inline! do
        Tantot.strategy(:sidekiq) do
          city = City.create name: 'foo'
          expect(SidekiqWatcher).to receive(:perform).with({City => {city.id => {"name" => [nil, 'foo']}}})
        end
      end
    end
  end
end
