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

  describe '.watch' do

    let(:watcher_instance) { double }

    before do
      stub_class("TestWatcher") { include Tantot::Watcher }
      allow(TestWatcher).to receive(:new).and_return(watcher_instance)
    end

    [true, false].each do |use_after_commit_callbacks|
      context "using after_commit hooks: #{use_after_commit_callbacks}" do
        before { allow(Tantot.config).to receive(:use_after_commit_callbacks).and_return(use_after_commit_callbacks) }

        context "watching an attribute" do
          before do
            stub_model(:city) do
              watch TestWatcher, :name
            end
          end

          it "doesn't call back when the attribute doesn't change" do
            Tantot.collector.run do
              City.create
              expect(watcher_instance).not_to receive(:perform)
            end
          end

          it "calls back when the attribute changes (on creation)" do
            Tantot.collector.run do
              city = City.create name: 'foo'
              expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
            end
          end

          it "calls back on model update" do
            city = City.create!
            city.reload
            Tantot.collector.sweep(:bypass)

            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
            Tantot.collector.run do
              city.name = "foo"
              city.save
            end
          end

          it "calls back on model destroy" do
            city = City.create!(name: 'foo')
            city.reload
            Tantot.collector.sweep(:bypass)

            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => ['foo']}}}))
            Tantot.collector.run do
              city.destroy
            end
          end

          it "calls back once per model even when updated more than once" do
            Tantot.collector.run do
              city = City.create! name: 'foo'
              city.name = 'bar'
              city.save
              city.name = 'baz'
              city.save
              expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo', 'bar', 'baz']}}}))
            end
          end

          it "allows to call a watcher mid-stream" do
            Tantot.collector.run do
              city = City.create name: 'foo'
              expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
              Tantot.collector.sweep(:inline)
              city.name = 'bar'
              city.save
              expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => ['foo', 'bar']}}}))
            end
          end
        end
      end
    end

    context "detailed format" do
      let(:watcher_instance) { double }
      before do
        stub_class("DetailedTestWatcher") do
          include Tantot::Watcher

          watcher_options format: :detailed
        end
        allow(DetailedTestWatcher).to receive(:new).and_return(watcher_instance)
        stub_model(:city) do
          watch 'detailed_test', :name
        end
      end

      it "should output a detailed array of changes" do
        Tantot.collector.run do
          city = City.create! name: 'foo'
          city.name = 'bar'
          city.save
          expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [[nil, 'foo'], ['foo', 'bar']]}}}))
        end
      end
    end

    context "on multiple models" do
      before do
        stub_model(:city) do
          watch TestWatcher, :name, :country_id
        end
        stub_model(:country) do
          watch TestWatcher, :country_code
        end
      end

      it "calls back once per watch when multiple watched models change" do
        country = Country.create!(country_code: "CDN")
        city = City.create!(name: "Quebec", country_id: country.id)
        country.reload
        city.reload
        Tantot.collector.sweep(:bypass)

        expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => ['Quebec', 'foo', 'bar'], "country_id" => [country.id, nil]}}, Country => {country.id => {"country_code" => ['CDN', 'US']}}}))
        Tantot.collector.run do
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
      let(:watchA_instance) { double }
      let(:watchB_instance) { double }
      before do
        stub_class("TestWatcherA") { include Tantot::Watcher }
        stub_class("TestWatcherB") { include Tantot::Watcher }
        allow(TestWatcherA).to receive(:new).and_return(watchA_instance)
        allow(TestWatcherB).to receive(:new).and_return(watchB_instance)
        stub_model(:city) do
          watch TestWatcherA, :name, :country_id
          watch TestWatcherB, :rating
        end
        stub_model(:country) do
          watch TestWatcherA, :country_code
          watch TestWatcherB, :name, :rating
        end
      end

      it "calls each watcher once for multiple models" do
        country = Country.create!(country_code: "CDN")
        city = City.create!(name: "Quebec", country_id: country.id, rating: 12)
        country.reload
        city.reload
        expect(watchA_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => ['Quebec', 'foo', 'bar'], "country_id" => [country.id, nil]}}, Country => {country.id => {"country_code" => ['CDN', 'US']}}}))
        # WatchB receives the last value of rating since it has been destroyed
        expect(watchB_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"rating" => [12]}}}))
        Tantot.collector.sweep(:bypass)

        Tantot.collector.run do
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

    context 'watching all attributes' do
      before do
        stub_model(:city) do
          watch TestWatcher
        end
      end

      it "should watch all changes" do
        Tantot.collector.run do
          city = City.create name: 'foo'
          expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"id" => [nil, city.id], "name" => [nil, "foo"]}}}))
        end
      end

      it "should also watch on destroy, but when watching all attributes, change hash is empty" do
        city = City.create!(name: 'foo')
        city.reload
        Tantot.collector.sweep(:bypass)

        expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {}}}))
        Tantot.collector.run do
          city.destroy
        end
      end
    end

    context 'with an additional `if` statement' do

      [:no, :some].each do |attribute_opt|
        context "with #{attribute_opt.to_s} attributes" do
          let(:condition) { double }
          before do
            c = condition
            watch_params = [TestWatcher]
            watch_params << :id if attribute_opt == :some
            watch_params << {if: -> { c.passed? }}
            stub_model(:city) do
              watch(*watch_params)
            end
          end

          it "should fail if the condition is false" do
            Tantot.collector.run do
              expect(condition).to receive(:passed?).once.and_return(false)
              City.create!
              expect(watcher_instance).not_to receive(:perform)
            end
          end

          it "should pass if the condition is true" do
            Tantot.collector.run do
              expect(condition).to receive(:passed?).once.and_return(true)
              City.create!
              expect(watcher_instance).to receive(:perform)
            end
          end
        end
      end
    end

    context 'using a block' do
      let(:value) { {changes: 0} }
      let(:changes) { {obj: nil} }
      before do
        v = value
        c = changes
        stub_model(:city) do
          watch {|changes| v[:changes] += 1; c[:obj] = changes}
        end
      end

      it "should call the block" do
        city = nil
        Tantot.collector.run do
          city = City.create!
        end
        expect(value[:changes]).to eq(1)
        expect(changes[:obj]).to eq(Tantot::Changes::ById.new({city.id => {"id" => [nil, 1]}}))
      end

      it "call a single time if multiple changes occur" do
        Tantot.collector.run do
          3.times { City.create! }
        end
        expect(value[:changes]).to eq(1)
        expect(changes[:obj]).to eq(Tantot::Changes::ById.new({1=>{"id"=>[nil, 1]}, 2=>{"id"=>[nil, 2]}, 3=>{"id"=>[nil, 3]}}))
      end
    end

    context 'on:' do

      context ':create' do
        before do
          stub_model(:city) do
            watch TestWatcher, on: :create
          end
        end

        it "should only watch creation" do
          city = nil
          Tantot.collector.run do
            city = City.create!
            expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"id" => [nil, city.id]}}}))
          end
          Tantot.collector.run do
            city = City.find(city)
            city.name = 'foo'
            city.save
          end
          Tantot.collector.run do
            city = City.find(city)
            city.destroy
          end
        end
      end

      context ':update' do
        before do
          stub_model(:city) do
            watch TestWatcher, on: :update
          end
        end

        it "should only watch update" do
          city = nil
          Tantot.collector.run do
            city = City.create!
            expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
          end
          Tantot.collector.run do
            city = City.find(city)
            city.name = 'foo'
            city.save
          end
          Tantot.collector.run do
            city = City.find(city)
            city.destroy
          end
        end
      end

      context ':destroy' do
        before do
          stub_model(:city) do
            watch TestWatcher, on: :destroy
          end
        end

        it "should only watch destruction" do
          city = nil
          Tantot.collector.run do
            city = City.create!
            expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {}}}))
          end
          Tantot.collector.run do
            city = City.find(city)
            city.name = 'foo'
            city.save
          end
          Tantot.collector.run do
            city = City.find(city)
            city.destroy
          end
        end
      end
    end
  end # describe '.watch'
end
