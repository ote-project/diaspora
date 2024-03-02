# frozen_string_literal: true
require 'database_cleaner/active_record'

# ActiveRecord::Base.logger = Logger.new(STDOUT)
# ActiveRecord::Base.logger.level = Logger::DEBUG

module ActiveSupport
  class TimeWithZone
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
      run_test do
        sym_params = {id: Dse::get_input_int("post_id")}.freeze
        dr = make_dse_recorder
        swap_in_params(sym_params) do
          dr.start do
            suppress_and_print(ActiveRecord::RecordNotFound, ActiveRecord::SerializationTypeMismatch) do
              sign_in_symbolic_user
              get :show, params: sym_params
            end
          end
        end
        Dse::write_transcript(dr)
      end
    end
  end
end

describe PeopleController, type: :controller do
  include DseHelpers

  describe "#show" do
    it "runs" do
      run_test do
        sym_params = {id: Dse::get_input_str("person_guid")}.freeze
        dr = make_dse_recorder
        swap_in_params(sym_params) do
          dr.start do
            suppress_and_print(ActiveRecord::RecordNotFound, ActiveRecord::SerializationTypeMismatch) do
              sign_in_symbolic_user
              get :show, params: sym_params
            end
          end
        end
        Dse::write_transcript(dr)
      end
    end
  end
end
