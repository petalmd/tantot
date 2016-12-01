require "spec_helper"

describe Tantot do
  it "has a version number" do
    expect(Tantot::VERSION).not_to be nil
  end

  describe '.derive_watcher' do
    class TestWatcher
      include Tantot::Watcher
    end

    class WrongWatcher
    end

    module Foo
      class BarWatcher
        include Tantot::Watcher
      end
    end

    specify { expect { described_class.derive_watcher('foo') }.to raise_error(Tantot::UnderivableWatcher) }
    specify { expect { described_class.derive_watcher(WrongWatcher) }.to raise_error(Tantot::UnderivableWatcher) }
    specify { expect(described_class.derive_watcher(TestWatcher)).to eq(TestWatcher) }
    specify { expect(described_class.derive_watcher(Foo::BarWatcher)).to eq(Foo::BarWatcher) }
    specify { expect(described_class.derive_watcher('test')).to eq(TestWatcher) }
    specify { expect(described_class.derive_watcher('foo/bar')).to eq(Foo::BarWatcher) }
  end

  [true, false].each do |use_after_commit_callbacks|
    context "using after_commit hooks: #{use_after_commit_callbacks}" do
      before { Tantot.config.use_after_commit_callbacks = use_after_commit_callbacks }

      let(:watcher) { stub_const("TestWatcher", Class.new) { include Tantot::Watcher } }
      let(:watcher_instance) { double }

      before do
        allow(watcher).to receive(:new).and_return(watcher_instance)
        allow(watcher).to receive(:included_modules).and_return([Tantot::Watcher])
      end

      context "watching an attribute" do
        before do
          w = watcher
          stub_model(:city) do
            watch w, :name
          end
        end

        it "doesn't call back when the attribute doesn't change" do
          Tantot.strategy(:atomic) do
            City.create
            expect(watcher_instance).not_to receive(:perform)
          end
        end

        it "calls back when the attribute changes (on creation)" do
          Tantot.strategy(:atomic) do
            city = City.create name: 'foo'
            expect(watcher_instance).to receive(:perform).with({City => {city.id => {"name" => [nil, 'foo']}}})
          end
        end

        it "calls back on model update" do
          city = City.create!
          city.reload
          expect(watcher_instance).to receive(:perform).with({City => {city.id => {"name" => [nil, 'foo']}}})
          Tantot.strategy(:atomic) do
            city.name = "foo"
            city.save
          end
        end

        it "calls back on model destroy" do
          city = City.create!(name: 'foo')
          city.reload
          expect(watcher_instance).to receive(:perform).with({City => {city.id => {"name" => ['foo']}}})
          Tantot.strategy(:atomic) do
            city.destroy
          end
        end

        it "calls back once per model even when updated more than once" do
          Tantot.strategy(:atomic) do
            city = City.create! name: 'foo'
            city.name = 'bar'
            city.save
            city.name = 'baz'
            city.save
            expect(watcher_instance).to receive(:perform).once.with({City => {city.id => {"name" => [nil, 'foo', 'bar', 'baz']}}})
          end
        end

        it "allows to call a watcher mid-stream" do
          Tantot.strategy(:atomic) do
            city = City.create name: 'foo'
            expect(watcher_instance).to receive(:perform).with({City => {city.id => {"name" => [nil, 'foo']}}})
            Tantot.strategy.join(watcher)
            city.name = 'bar'
            city.save
            expect(watcher_instance).to receive(:perform).with({City => {city.id => {"name" => ['foo', 'bar']}}})
          end
        end
      end

      context "on multiple models" do
        before do
          w = watcher
          stub_model(:city) do
            watch w, :name, :country_id
          end
          stub_model(:country) do
            watch w, :country_code
          end
        end

        it "calls back once per watch when multiple watched models change" do
          country = Country.create!(country_code: "CDN")
          city = City.create!(name: "Quebec", country_id: country.id)
          country.reload
          city.reload
          expect(watcher_instance).to receive(:perform).once.with({City => {city.id => {"name" => ['Quebec', 'foo', 'bar'], "country_id" => [country.id, nil]}}, Country => {country.id => {"country_code" => ['CDN', 'US']}}})
          Tantot.strategy(:atomic) do
            city.name = "foo"
            city.save
            city.name = "bar"
            city.save
            city.country_id = nil
            city.save
            country.country_code = 'US'
            country.save
            city.destroy
          end
        end
      end

      context "with multiple watchers" do
        let(:watchA) { stub_const("TestWatcherA", Class.new) { include Tantot::Watcher } }
        let(:watchB) { stub_const("TestWatcherB", Class.new) { include Tantot::Watcher } }
        let(:watchA_instance) { double }
        let(:watchB_instance) { double }
        before do
          allow(watchA).to receive(:new).and_return(watchA_instance)
          allow(watchA).to receive(:included_modules).and_return([Tantot::Watcher])
          allow(watchB).to receive(:new).and_return(watchB_instance)
          allow(watchB).to receive(:included_modules).and_return([Tantot::Watcher])
          wA = watchA
          wB = watchB
          stub_model(:city) do
            watch wA, :name, :country_id
            watch wB, :rating
          end
          stub_model(:country) do
            watch wA, :country_code
            watch wB, :name, :rating
          end
        end

        it "calls each watcher once for multiple models" do
          country = Country.create!(country_code: "CDN")
          city = City.create!(name: "Quebec", country_id: country.id, rating: 12)
          country.reload
          city.reload
          expect(watchA_instance).to receive(:perform).once.with({City => {city.id => {"name" => ['Quebec', 'foo', 'bar'], "country_id" => [country.id, nil]}}, Country => {country.id => {"country_code" => ['CDN', 'US']}}})
          # WatchB receives the last value of rating since it has been destroyed
          expect(watchB_instance).to receive(:perform).once.with({City => {city.id => {"rating" => [12]}}})
          Tantot.strategy(:atomic) do
            city.name = "foo"
            city.save
            city.name = "bar"
            city.save
            city.country_id = nil
            city.save
            country.country_code = 'US'
            country.save
            city.destroy
          end
        end
      end
    end
  end
end
