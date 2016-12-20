require "spec_helper"

if defined?(::Chewy)

  describe Tantot::Extensions::Chewy do

    [nil, :self, :class_method, :block].product([:some, :all]).each do |backreference_opt, attribute_opt|
      context "should update indexes using backreference: #{backreference_opt.inspect}, attributes: #{attribute_opt}" do
        let(:chewy_type) { double }

        before do
          watch_index_options = {}
          watch_index_params = ['foo']
          watch_index_options[:only] = :id if attribute_opt == :some

          block_callback = proc do |changes|
            self.yielded_changes = changes
            [1, 2, 3]
          end

          case backreference_opt
          when nil, :block
          when :self
            watch_index_options[:method] = :self
          when :class_method
            watch_index_options[:method] = :class_get_ids
          end

          watch_index_params << watch_index_options

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
        end

        it "should update accordingly" do
          city1 = city2 = nil

          Tantot.manager.run do
            city1 = City.create!(name: 'foo')
            city2 = City.create!(name: 'bar')

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
            if attribute_opt == :some
              expect(City.yielded_changes).to eq(Tantot::Changes::ById.new({city1.id => {"id" => [nil, city1.id]}, city2.id => {"id" => [nil, city2.id]}}))
            else
              expect(City.yielded_changes).to eq(Tantot::Changes::ById.new({city1.id => {"id" => [nil, city1.id], "name" => [nil, 'foo']}, city2.id => {"id" => [nil, city2.id], "name" => [nil, 'bar']}}))
            end
          end

        end
      end
    end

    context "allow registering an index watch on self (all attributes, destroy)" do
      let(:chewy_type) { double }

      before do
        stub_model(:city) do
          watch_index 'foo'
        end
      end

      it "should update accordingly" do
        city = City.create!
        Tantot.manager.sweep(:bypass)

        Tantot.manager.run do
          city.destroy

          expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
          expect(chewy_type).to receive(:update_index).with([city.id], {})
        end
      end
    end

    context "allow registering an index watch on self (all attributes, destroy, block)" do
      let(:chewy_type) { double }

      before do
        stub_model(:city) do
          watch_index 'foo' do |changes|
            changes.ids
          end
        end
      end

      it "should update accordingly" do
        city = City.create!
        Tantot.manager.sweep(:bypass)

        Tantot.manager.run do
          city.destroy

          expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
          expect(chewy_type).to receive(:update_index).with([city.id], {})
        end
      end
    end

    context "allow returning nothing in a callback" do
      before do
        stub_model(:city) do
          watch_index('foo') { 1 if false }
          watch_index('bar') { [] }
          watch_index('baz') { nil }
        end
      end

      it "should update accordingly" do
        Tantot.manager.run do
          City.create!

          expect(Chewy).not_to receive(:derive_type)
        end
      end
    end

    context "association" do
      context "simple" do
        let(:chewy_type) { double }
        before do
          stub_model(:city) do
            belongs_to :country

            has_many :streets

            watch_index 'country#countries', only: :name, association: :country
          end

          stub_model(:country) do
            has_many :cities

            watch_index 'city#cities', only: :name, association: :cities
          end
        end

        it "allows automatically watching a :belongs_to association as a backreference" do
          Tantot.manager.run do
            country1 = Country.create! id: 111
            country2 = Country.create! id: 222
            city = City.create id: 999, country: country1
            city.reload
            Tantot.manager.sweep(:bypass)

            city.country = country2
            city.save

            expect(Chewy).to receive(:derive_type).with('country#countries').and_return(chewy_type)
            expect(chewy_type).to receive(:update_index).with([country1.id, country2.id], {})
          end
        end

        it "allows automatically watching an :has_many association as a backreference" do
          Tantot.manager.run do
            country = Country.create! id: 111
            country.cities.create id: 990
            country.cities.create id: 991
            country.reload
            Tantot.manager.sweep(:bypass)

            country.name = "foo"
            country.save

            expect(Chewy).to receive(:derive_type).with('city#cities').and_return(chewy_type)
            expect(chewy_type).to receive(:update_index).with([990, 991], {})
          end
        end
      end

      context "has_many through" do
        context "has_many -> belongs_to" do
          let(:chewy_type) { double }
          before do
            stub_model(:color) do
              belongs_to :group
            end

            stub_model(:user) do
              has_many :memberships
              has_many :groups, through: :memberships

              watch_index 'groups#group', only: :username, association: :groups
            end

            stub_model(:membership) do
              belongs_to :user
              belongs_to :group

              has_many :colors, through: :group
            end

            stub_model(:group) do
              has_many :colors
              has_many :memberships
              has_many :users, through: :memberships
            end
          end

          it 'updates accordingly' do
            Tantot.manager.run do

              user = User.create! id: 111
              group = Group.create! id: 999
              Membership.create! id: 555, user: user, group: group
              Tantot.manager.sweep(:bypass)

              user.username = 'foo'
              user.save

              expect(Chewy).to receive(:derive_type).with('groups#group').and_return(chewy_type)
              expect(chewy_type).to receive(:update_index).with([999], {})
            end
          end
        end

        context "has_many -> has_many" do
          let(:chewy_type) { double }
          before do
            stub_model(:street) do
              belongs_to :city
            end

            stub_model(:city) do
              belongs_to :country

              has_many :streets
            end

            stub_model(:country) do
              has_many :cities
              has_many :streets, through: :cities

              watch_index 'streets#street', only: :name, association: :streets
            end
          end

          it "updates accordingly" do
            Tantot.manager.run do
              country = Country.create! id: 111
              city = City.create! id: 999, country: country
              Street.create! id: 555, city: city
              country.reload
              Tantot.manager.sweep(:bypass)

              country.name = "foo"
              country.save

              expect(Chewy).to receive(:derive_type).with('streets#street').and_return(chewy_type)
              expect(chewy_type).to receive(:update_index).with([555], {})
            end
          end
        end

        context "belongs_to -> has_many" do
          let(:chewy_type) { double }
          before do
            stub_model(:color) do
              belongs_to :group
            end

            stub_model(:user) do
              has_many :memberships
            end

            stub_model(:group) do
              has_many :memberships
              has_many :colors
            end

            stub_model(:membership) do
              belongs_to :group

              has_many :colors, through: :group

              watch_index 'colors#color', association: :colors
            end
          end

          it "updates accordingly" do
            Tantot.manager.run do
              group = Group.create! id: 111
              group.colors.create! id: 222, name: 'red'
              membership = Membership.create id: 333, group: group
              Tantot.manager.sweep(:bypass)
              membership.reload

              membership.name = "foo"
              membership.save

              expect(Chewy).to receive(:derive_type).with('colors#color').and_return(chewy_type)
              expect(chewy_type).to receive(:update_index).with([222], {})
            end
          end
        end

        context "has_many through: nested" do
          let(:chewy_type) { double }
          before do
            stub_model(:color) do
              belongs_to :group
            end

            stub_model(:user) do
              has_many :memberships
              has_many :colors, through: :memberships, source: :colors

              watch_index 'colors#color', association: :colors
            end

            stub_model(:group) do
              has_many :memberships
              has_many :colors
            end

            stub_model(:membership) do
              belongs_to :group
              belongs_to :user

              has_many :colors, through: :group
            end
          end

          it "updates accordingly" do
            Tantot.manager.run do
              group = Group.create! id: 111
              group.colors.create! id: 222, name: 'red'
              user = User.create id: 444
              Membership.create id: 333, group: group, user: user
              Tantot.manager.sweep(:bypass)
              user.reload

              user.username = "foo"
              user.save

              expect(Chewy).to receive(:derive_type).with('colors#color').and_return(chewy_type)
              expect(chewy_type).to receive(:update_index).with([222], {})
            end
          end


        end
      end
    end
  end

  describe "Chewy.strategy" do
    before do
      allow(Tantot.config).to receive(:sweep_on_push).and_return(true)
      stub_model(:city) do
        watch_index('foo')
      end
    end

    it "should bypass if Chewy.strategy is :bypass" do
      expect(Chewy).not_to receive(:derive_type)
      Chewy.strategy :bypass do
        City.create!
      end
    end
  end

end
