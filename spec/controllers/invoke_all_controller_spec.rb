# frozen_string_literal: true
require 'jruby/dse/extensions/equality'
require 'database_cleaner/active_record'

# ActiveRecord::Base.logger = Logger.new(STDOUT)
# ActiveRecord::Base.logger.level = Logger::DEBUG

module ActiveSupport
  class TimeWithZone
    include Dse::SymbolicEquality

    def with_sym_ast(ast)
      dup.set_sym_ast ast
    end
  end
end

class << Time
  alias_method :orig_now, :now
  def now
    Dse.get_cached_var(:now) { orig_now }
  end
end

describe PostsController, type: :controller do
  include DseHelpers

  describe "#show" do
    it "runs" do
      sym_params = {id: Dse::get_input_int("post_id")}.freeze
      run_test :show, sym_params
    end
  end
end

describe PeopleController, type: :controller do
  include DseHelpers

  describe "#show" do
    it "runs" do
      sym_params = {id: Dse::get_input_str("person_guid")}.freeze
      run_test :show, sym_params
    end
  end

  describe "#stream" do
    it "runs" do
      sym_params = {person_id: Dse::get_input_str("person_guid")}.freeze
      run_test :stream, sym_params, :format => :json
    end
  end
end

describe CommentsController, type: :controller do
  include DseHelpers

  describe "#index" do
    it "runs" do
      sym_params = {post_id: Dse::get_input_int("post_id")}.freeze
      run_test :index, sym_params, :format => :json
    end
  end
end

describe ConversationsController, type: :controller do
  include DseHelpers

  describe "#index" do
    it "runs" do
      sym_params = {conversation_id: Dse::get_input_int("conversation_id")}.freeze
      run_test :index, sym_params
    end
  end
end
