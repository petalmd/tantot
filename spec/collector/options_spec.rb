require "spec_helper"

describe Tantot::Agent do
  describe "options" do
    let(:watcher_instance) { double }

    before do
      stub_class("TestWatcher") { include Tantot::Watcher }
      allow(TestWatcher).to receive(:new).and_return(watcher_instance)
    end

    context 'with an additional `if` statement' do
      [:no, :some].each do |attribute_opt|
        context "with #{attribute_opt.to_s} attributes" do
          let(:condition) { double }
          before do
            c = condition
            watch_params = [TestWatcher]
            hash = {}
            hash[:only] = :id if attribute_opt == :some
            hash[:if] = -> { c.passed? }
            watch_params << hash
            stub_model(:city) do
              watch(*watch_params)
            end
          end

          it "should fail if the condition is false" do
            Tantot.manager.run do
              expect(condition).to receive(:passed?).once.and_return(false)
              City.create!
              expect(watcher_instance).not_to receive(:perform)
            end
          end

          it "should pass if the condition is true" do
            Tantot.manager.run do
              expect(condition).to receive(:passed?).once.and_return(true)
              City.create!
              expect(watcher_instance).to receive(:perform)
            end
          end
        end
      end
    end

    context 'always:' do
      context 'when watching everything' do
        before do
          stub_model(:city) do
            belongs_to :country

            watch TestWatcher, always: :country_id
          end

          stub_model(:country) do
            has_many :cities
          end
        end

        it "should watch all changes including the always field even when not changed" do
          Tantot.manager.run do
            city = City.create name: 'foo'
            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"id" => [nil, city.id], "name" => [nil, "foo"], "country_id" => [nil]}}}))
          end
        end

        it "should watch all changes including the always field even when changed" do
          Tantot.manager.run do
            country = Country.create
            city = City.create name: 'foo', country: country
            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"id" => [nil, city.id], "name" => [nil, "foo"], "country_id" => [nil, country.id]}}}))
          end
        end

        it "should send the field value when destroyed" do
          Tantot.manager.run do
            country = Country.create
            city = City.create name: 'foo', country: country
            Tantot.manager.sweep(:bypass)

            city.reload

            city.destroy
            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"country_id" => [country.id]}}}))
          end
        end
      end

      context "when watching specific attributes" do
        before do
          stub_model(:city) do
            belongs_to :country

            watch TestWatcher, only: :name, always: :country_id
          end

          stub_model(:country) do
            has_many :cities
          end
        end

        it "should watch all changes including the always field even when not changed" do
          Tantot.manager.run do
            city = City.create name: 'foo'
            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, "foo"], "country_id" => [nil]}}}))
          end
        end

        it "should watch all changes including the always field even when changed" do
          Tantot.manager.run do
            country = Country.create
            city = City.create name: 'foo', country: country
            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, "foo"], "country_id" => [nil, country.id]}}}))
          end
        end

        it "should send the field value when destroyed" do
          Tantot.manager.run do
            country = Country.create
            city = City.create name: 'foo', country: country
            Tantot.manager.sweep(:bypass)

            city.reload

            city.destroy
            expect(watcher_instance).to receive(:perform).with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => ['foo'], "country_id" => [country.id]}}}))
          end
        end

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
          Tantot.manager.run do
            city = City.create!
            expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"id" => [nil, city.id]}}}))
          end
          Tantot.manager.run do
            city = City.find(city)
            city.name = 'foo'
            city.save
          end
          Tantot.manager.run do
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
          Tantot.manager.run do
            city = City.create!
            expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {"name" => [nil, 'foo']}}}))
          end
          Tantot.manager.run do
            city = City.find(city)
            city.name = 'foo'
            city.save
          end
          Tantot.manager.run do
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
          Tantot.manager.run do
            city = City.create!
            expect(watcher_instance).to receive(:perform).once.with(Tantot::Changes::ByModel.new({City => {city.id => {}}}))
          end
          Tantot.manager.run do
            city = City.find(city)
            city.name = 'foo'
            city.save
          end
          Tantot.manager.run do
            city = City.find(city)
            city.destroy
          end
        end
      end
    end
  end
end
