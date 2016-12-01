require "spec_helper"

describe Tantot do
  it "has a version number" do
    expect(Tantot::VERSION).not_to be nil
  end

  [true, false].each do |use_after_commit_callbacks|
    context "using after_commit hooks: #{use_after_commit_callbacks}" do
      before { Tantot.config.use_after_commit_callbacks = use_after_commit_callbacks }

      context "watching an attribute" do
        let(:watch) { double }
        before do
          w = watch
          stub_model(:city) do
            watch w, :name
          end
        end

        it "doesn't call back when the attribute doesn't change" do
          Tantot.strategy(:atomic) do
            City.create
            expect(watch).not_to receive(:perform)
          end
        end

        it "calls back when the attribute changes (on creation)" do
          Tantot.strategy(:atomic) do
            city = City.create name: 'foo'
            expect(watch).to receive(:perform).with({"City" => {city.id => {"name" => [nil, 'foo']}}})
          end
        end

        it "calls back on model update" do
          city = City.create!
          city.reload
          expect(watch).to receive(:perform).with({"City" => {city.id => {"name" => [nil, 'foo']}}})
          Tantot.strategy(:atomic) do
            city.name = "foo"
            city.save
          end
        end

        it "calls back on model destroy" do
          city = City.create!(name: 'foo')
          city.reload
          expect(watch).to receive(:perform).with({"City" => {city.id => {"name" => ['foo']}}})
          Tantot.strategy(:atomic) do
            city.destroy
          end
        end

        it "calls back once per model even when updated more than once" do
          city = City.create!
          city.reload
          expect(watch).to receive(:perform).once.with({"City" => {city.id => {"name" => [nil, 'foo', 'bar']}}})
          Tantot.strategy(:atomic) do
            city.name = "foo"
            city.save
            city.name = "bar"
            city.save
          end
        end
      end

      context "on multiple models" do
        let(:watch) { double }
        before do
          w = watch
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
          expect(watch).to receive(:perform).once.with({"City" => {city.id => {"name" => ['Quebec', 'foo', 'bar'], "country_id" => [country.id, nil]}}, "Country" => {country.id => {"country_code" => ['CDN', 'US']}}})
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
        let(:watchA) { double }
        let(:watchB) { double }
        before do
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
          expect(watchA).to receive(:perform).once.with({"City" => {city.id => {"name" => ['Quebec', 'foo', 'bar'], "country_id" => [country.id, nil]}}, "Country" => {country.id => {"country_code" => ['CDN', 'US']}}})
          # WatchB receives the last value of rating since it has been destroyed
          expect(watchB).to receive(:perform).once.with({"City" => {city.id => {"rating" => [12]}}})
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
