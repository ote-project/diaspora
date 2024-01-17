# frozen_string_literal: true

#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

ENV["RAILS_ENV"] ||= "test"

require 'coveralls'
Coveralls.wear!('rails')

require File.join(File.dirname(__FILE__), "..", "config", "environment")
require Rails.root.join("spec", "helper_methods")
require "rspec/rails"
require "webmock/rspec"
require "factory_girl"
require "sidekiq/testing"
require "shoulda/matchers"
require "diaspora_federation/schemas"

include HelperMethods

Dir["#{File.dirname(__FILE__)}/shared_behaviors/**/*.rb"].each do |f|
  require f
end

RSpec::Matchers.define_negated_matcher :remain, :change

ProcessedImage.enable_processing = false
UnprocessedImage.enable_processing = false

def alice
  @alice ||= User.find_by(username: "alice")
end

def bob
  @bob ||= User.find_by(username: "bob")
end

def eve
  @eve ||= User.find_by(username: "eve")
end

def local_luke
  @local_luke ||= User.find_by(username: "luke")
end

def local_leia
  @local_leia ||= User.find_by(username: "leia")
end

def remote_raphael
  @remote_raphael ||= Person.find_by(diaspora_handle: "raphael@remote.net")
end

def peter
  @peter ||= User.find_by(username: "peter")
end

def photo_fixture_name
  @photo_fixture_name = File.join(File.dirname(__FILE__), "fixtures", "button.png")
end

def jwks_file_path
  @jwks_file = File.join(File.dirname(__FILE__), "fixtures", "jwks.json")
end

def valid_client_assertion_path
  @valid_client_assertion = File.join(File.dirname(__FILE__), "fixtures", "valid_client_assertion.txt")
end

def client_assertion_with_tampered_sig_path
  @client_assertion_with_tampered_sig = File.join(File.dirname(__FILE__), "fixtures",
                                                  "client_assertion_with_tampered_sig.txt")
end

def client_assertion_with_nonexistent_kid_path
  @client_assertion_with_nonexistent_kid = File.join(File.dirname(__FILE__), "fixtures",
                                                     "client_assertion_with_nonexistent_kid.txt")
end

def client_assertion_with_nonexistent_client_id_path
  @client_assertion_with_nonexistent_client_id = File.join(File.dirname(__FILE__), "fixtures",
                                                           "client_assertion_with_nonexistent_client_id.txt")
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
fixture_builder_file = "#{File.dirname(__FILE__)}/support/fixture_builder.rb"
support_files = Dir["#{File.dirname(__FILE__)}/support/**/*.rb"] - [fixture_builder_file]
support_files.each {|f| require f }
require fixture_builder_file

RSpec.configure do |config|
  config.fixture_path = Rails.root.join("spec", "fixtures")
  config.global_fixtures = :all

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.mock_with :rspec

  config.example_status_persistence_file_path = "tmp/rspec-persistance.txt"

  config.render_views
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!

  config.before(:each) do
    I18n.locale = :en
    stub_request(:post, "https://pubsubhubbub.appspot.com/")
    $process_queue = false
  end

  config.expect_with :rspec do |expect_config|
    expect_config.syntax = :expect
  end

  config.after(:all) do
    `rm -rf #{Rails.root}/tmp/uploads/*`
  end

  # Reset overridden settings
  config.after(:each) do
    AppConfig.reset_dynamic!
  end

  # Reset test mails
  config.after(:each) do
    ActionMailer::Base.deliveries.clear
  end

  # Reset gon
  config.after(:each) do
    RequestStore.store[:gon].gon.clear unless RequestStore.store[:gon].nil?
  end

  config.include FactoryGirl::Syntax::Methods

  config.include JSON::SchemaMatchers
  config.json_schemas[:archive_schema] = "lib/schemas/archive-format.json"

  JSON::Validator.add_schema(
    JSON::Schema.new(
      DiasporaFederation::Schemas.federation_entities,
      Addressable::URI.parse(DiasporaFederation::Schemas::FEDERATION_ENTITIES_URI)
    )
  )
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

shared_context suppress_csrf_verification: :none do
  before do
    ActionController::Base.allow_forgery_protection = true
  end
end

def swap_in_params(sym_params)
	sym_params = sym_params.transform_values(&:to_s).freeze  # Convert values to strings, since params are strings.

	klass = ActionController::Parameters
	klass.alias_method :orig_hash_access, :[]
	klass.define_method :[] do |key|
		sym_params.fetch(key) { |k| orig_hash_access k }
	end

	yield
ensure
	klass.undef_method :[]
	klass.alias_method :[], :orig_hash_access
	klass.undef_method :orig_hash_access
end

# Makes the user object's ID field return a symbolic variable.
# Call this function on the user currently logged in.
def make_user_id_symbolic(user, id_var_name)
  user.define_singleton_method(:id) do
    res = super()
    raise "User ID is not an integer" unless res.is_a?(Integer)
    res.to_symbolic_var(id_var_name)
  end
end

def make_dse_recorder
  dr = Dse::Recorder.new
  dr.model ActiveModel::Type::Integer, :deserialize, "RAILS_DESERIALIZE_INTEGER"
  dr.model ActiveModel::Type::Integer, :serialize, "RAILS_SERIALIZE_INTEGER"

  dr.model ActiveModel::Type::Boolean, :deserialize, "RAILS_DESERIALIZE_BOOLEAN"
  dr.model ActiveModel::Type::Boolean, :serialize, "RAILS_SERIALIZE_BOOLEAN"

  dr.model ActiveRecord::Type::Text, :deserialize, "RAILS_DESERIALIZE_STRING"
  dr.model ActiveRecord::Type::Text, :serialize, "RAILS_SERIALIZE_STRING"

  dr.model ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString, :deserialize,
           "RAILS_DESERIALIZE_STRING"
  dr.model ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString, :serialize,
           "RAILS_SERIALIZE_STRING"

  dr.model ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter, :deserialize,
            "RAILS_DESERIALIZE_TIME"

  dr.model ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter, :serialize,
           "RAILS_SERIALIZE_TIME"

  dr
end

def suppress_and_print(*exception_classes)
  yield
rescue *exception_classes => e
  puts "Ignored Exception: #{e.class}: #{e.message}"
end

