# Tantot

[![Build Status](https://travis-ci.org/petalmd/tantot.svg?branch=master)](https://travis-ci.org/petalmd/tantot)

Tantot (french for _shortly_/_soon_)

Centralize and delay changes to multiple ActiveRecord models to offload processing of complex calculations caused by model mutations.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tantot'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tantot

## Usage

Tantot introduces new ActiveRecord callbacks that abstracts most of the usual boilerplate when managing changes, and also allows running callbacks in Sidekiq.

_More documentation to come!_

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/petalmd/tantot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

