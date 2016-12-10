require 'bundler'

# .gitignore
file '.gitignore', <<-CODE
!.keep
*.DS_Store
*.swo
*.swp
/.bundle
/.env.local
/coverage/*
/db/*.sqlite3
/log/*
/public/system
/public/assets
/tags
/tmp/*
/vendor/bundle
CODE

# Ruby Version
ruby_version = `ruby -v`.scan(/\d\.\d\.\d/).flatten.first

run "echo '#{ruby_version}' > ./.ruby-version"

file 'Gemfile', <<-CODE
source 'https://gems.ruby-china.org'

ruby '#{ruby_version}'

gem 'rails', '~> 5.0.0'
gem 'pg'
gem 'puma'
gem 'rack-cors'
# gem 'active_model_serializers', '~> 0.10.0'
gem 'jsonapi-resources'
# Cronjob schedulers that can be coded in the
# gem 'whenever', require: false
gem 'redis'
# gem "redis-rails"
# gem 'redis-namespace'
gem 'sidekiq'

group :development do
  # gem "capistrano"
  # gem 'capistrano-rails'
  # gem 'capistrano3-puma'
  gem 'listen'
  gem 'rack-mini-profiler', require: false
  gem 'rubocop', require: false
  gem 'spring'
  gem 'spring-commands-rspec'
end

group :development, :test do
  gem 'annotate'
  gem 'awesome_print'
  gem 'bullet'
  gem 'bundler-audit', '>= 0.5.0', require: false
  gem 'dotenv-rails'
  gem 'factory_girl_rails'
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'rspec-rails', '~> 3.5.0'
end

group :test do
  gem 'database_cleaner'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'timecop'
end
CODE

Bundler.with_clean_env do
  run 'bundle install --without production'
end

after_bundle do
  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end

# Config
# ----------------------------------------------------------------
# set config/application.rb
application  do
  <<-CODE
  # Set locale
  I18n.enforce_available_locales = true
  config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
  config.i18n.default_locale = :en
  CODE
end

# For Bullet (N+1 Problem)
inject_into_file 'config/environments/development.rb', after: 'config.file_watcher = ActiveSupport::EventedFileUpdateChecker' do
  <<-CODE
  # Bullet Setting (help to kill N + 1 query)
  config.after_initialize do
    Bullet.enable = true # enable Bullet gem, otherwise do nothing
    Bullet.alert = true # pop up a JavaScript alert in the browser
    Bullet.console = true #  log warnings to your browser's console.log
    Bullet.rails_logger = true #  add warnings directly to the Rails log
  end
  CODE
end

# Improve security
inject_into_file 'config/environments/production.rb', after: 'config.active_record.dump_schema_after_migration = false' do
<<-CODE
  # Sanitizing parameter
  config.filter_parameters += [/(password|private_token|api_endpoint)/i]
CODE
end

# set rubocop
get 'https://raw.githubusercontent.com/rails/rails/master/.rubocop.yml', '.rubocop.yml'

# set Chinese locale
get 'https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/zh-CN.yml', 'config/locales/zh-CN.yml'

file 'circle.yml', <<-CODE
database:
  override:
    - bin/setup
test:
  override:
    - COVERAGE=true bin/rake
CODE

# Initializer
# ----------------------------------------------------------------

# initializer 'active_model_serializer.rb', <<-CODE
# ActiveModelSerializers.config.adapter = :json_api
# CODE

initializer 'rack_mini_profiler.rb', <<-CODE
if ENV["RACK_MINI_PROFILER"].to_i > 0
  require "rack-mini-profiler"

  Rack::MiniProfilerRails.initialize!(Rails.application)
end
CODE

initializer 'cors.rb', <<-CODE
# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
CODE

file 'config/puma.rb', <<-CODE
# https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server

# The environment variable WEB_CONCURRENCY may be set to a default value based
# on dyno size. To manually configure this value use heroku config:set
# WEB_CONCURRENCY.
#
# Increasing the number of workers will increase the amount of resting memory
# your dynos use. Increasing the number of threads will increase the amount of
# potential bloat added to your dynos when they are responding to heavy
# requests.
#
# Starting with a low number of workers and threads provides adequate
# performance for most applications, even under load, while maintaining a low
# risk of overusing memory.
workers Integer(ENV.fetch("WEB_CONCURRENCY", 2))
threads_count = Integer(ENV.fetch("MAX_THREADS", 2))
threads(threads_count, threads_count)

preload_app!

rackup DefaultRackup
environment ENV.fetch("RAILS_ENV", "development")

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
  ActiveRecord::Base.establish_connection
end
CODE

# Test ENV
# ----------------------------------------------------------------
Bundler.with_clean_env do
  run 'bundle exec rails generate rspec:install'
end

file 'spec/rails_helper.rb', <<-CODE
ENV["RACK_ENV"] = "test"

require File.expand_path("../../config/environment", __FILE__)
abort("DATABASE_URL environment variable is set") if ENV["DATABASE_URL"]

require "rspec/rails"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.infer_base_class_for_anonymous_controllers = false
  config.infer_spec_type_from_file_location!
  config.use_transactional_fixtures = false
end

ActiveRecord::Migration.maintain_test_schema!
CODE

file 'spec/spec_helper.rb', <<-CODE
if ENV.fetch("COVERAGE", false)
  require "simplecov"

  if ENV["CIRCLE_ARTIFACTS"]
    dir = File.join(ENV["CIRCLE_ARTIFACTS"], "coverage")
    SimpleCov.coverage_dir(dir)
  end

  SimpleCov.start "rails"
end

# http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end

  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.order = :random
end
CODE

file 'spec/support/shoulda_matchers.rb', <<-CODE
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
CODE

file 'spec/support/factory_girl.rb', <<-CODE
RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
end
CODE

file 'spec/support/database_cleaner.rb', <<-CODE
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :deletion
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
CODE

# Rake DB Create
# ----------------------------------------------------------------
Bundler.with_clean_env do
  rails_command 'db:create'
end
