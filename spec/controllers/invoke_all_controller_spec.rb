# frozen_string_literal: true
require 'database_cleaner/active_record'

# ActiveRecord::Base.verbose_query_logs = true
# ActiveRecord::Base.logger.level = Logger::DEBUG

describe PostsController, type: :controller do
  describe "#show" do
    def sign_in_symbolic_user
      user_id = Dse::get_input_int("user_id")
      sign_in User.find(user_id), scope: :user
    end

    before(:example) do
      DatabaseCleaner.clean_with(:truncation)

      conn = ActiveRecord::Base.connection
      conn.disable_referential_integrity do
        ENV.fetch("DSE_DB_IN", "").lines.each do |sql|
          conn.execute(sql)
        end
      end
    end

    it "_runs" do
      suppress_and_print(ActiveRecord::RecordNotFound, ActiveRecord::SerializationTypeMismatch) do
        sign_in_symbolic_user
        get :show, params: {id: Dse::get_input_int("post_id")}
      end
    end

    it "runs" do
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
