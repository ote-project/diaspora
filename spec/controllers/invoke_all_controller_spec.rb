# frozen_string_literal: true
require 'database_cleaner/active_record'

module ActiveSupport
  class TimeWithZone
    def with_sym_ast(ast)
      # TODO(zhangwen): deduplicate this.
      symbolic_copy = dup
      symbolic_copy.define_singleton_method(:sym_ast) { ast }
      symbolic_copy
    end
  end
end

describe PostsController, type: :controller do
  self.use_transactional_tests = false

  describe "#show" do
    def sign_in_symbolic_user
      user_id = Dse::get_input_int("user_id")
      sign_in User.find(user_id), scope: :user
    end

    def run_test
      DatabaseCleaner.clean_with(:truncation)  # Clear the database.

      conn = ActiveRecord::Base.connection
      conn.begin_transaction joinable: false

      conn.disable_referential_integrity do
        Dse::get_db_setup_stmts.each do |sql|
          conn.execute(sql)
        end
      end

      yield
    ensure
      conn.rollback_transaction if conn.transaction_open?
    end

    # FIXME(zhangwen): de-duplicate this.
    it "_runs" do # Dry run.
      run_test do
        suppress_and_print(ActiveRecord::RecordNotFound, ActiveRecord::SerializationTypeMismatch) do
          sign_in_symbolic_user
          get :show, params: {id: Dse::get_input_int("post_id")}
        end
      end
    end

    it "runs" do
      run_test do
        sym_params = {id: Dse::get_input_int("post_id")}.freeze
        ActiveRecord::Base.connection.query_cache.clear
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
