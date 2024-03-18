# frozen_string_literal: true
require 'jruby/dse/extensions/equality'
require "jruby/dse/transcript_proto/expr_pb"
require 'database_cleaner/active_record'

# ActiveRecord::Base.logger = Logger.new(STDOUT)
# ActiveRecord::Base.logger.level = Logger::DEBUG

#region Redefinitions of Ruby and Rails methods
# FIXME(zhangwen): put these somewhere else?
class ActiveSupport::TimeWithZone
  include Dse::SymbolicEquality

  def with_sym_ast(ast)
    dup.set_sym_ast ast
  end
end

module ActiveRecord
  module AttributeMethods::Query
    def query_attribute(attr_name)
      value = self[attr_name]
      res = Dse::Recorder.ignore do
        case value
        when true        then true
        when false, nil  then false
        else
          column = self.class.columns_hash[attr_name]
          if column.nil?
            if Numeric === value || value !~ /[^0-9]/
              !value.to_i.zero?
            else
              return false if ActiveModel::Type::Boolean::FALSE_VALUES.include?(value)
              !value.blank?
            end
          elsif value.respond_to?(:zero?)
            !value.zero?
          else
            !value.blank?
          end
        end
      end

      if value.symbolic?
        res = res.with_sym_ast Dse::TranscriptProto::Expression.new(
          call: Dse::TranscriptProto::Call.new(
            function: "RAILS_QUERY_ATTRIBUTE",
            arguments: [value.sym_ast]
          )
        )
      end
      res
    end
  end

  module Inheritance::ClassMethods
    private
      def find_sti_class(type_name)
        type_name = base_class.type_for_attribute(inheritance_column).cast(type_name)

        descendants.sort_by(&:name).each do |klass| # TODO(zhangwen): is `sort_by` necessary?
          return klass if klass.name == type_name
        end

        subclass = begin
          if store_full_sti_class
            ActiveSupport::Dependencies.constantize(type_name)
          else
            compute_type(type_name)
          end
        rescue NameError
          raise SubclassNotFound,
            "The single-table inheritance mechanism failed to locate the subclass: '#{type_name}'. " \
            "This error is raised because the column '#{inheritance_column}' is reserved for storing the class in case of inheritance. " \
            "Please rename this column if you didn't intend it to be used for storing the inheritance class " \
            "or overwrite #{name}.inheritance_column to use another column for that information."
        end
        unless subclass == self || descendants.include?(subclass)
          raise SubclassNotFound, "Invalid single-table inheritance type: #{subclass.name} is not a subclass of #{name}"
        end
        subclass
      end
  end

  class Associations::Association
    private
      def skip_statement_cache?(_scope)
        true
      end
  end
end

class << Time
  def now
    Dse::get_input_ts("now")
  end
end

class << NilClass
  def blank?
    nil?  # This will record a nil check.
  end
end

class << String
  alias_method :orig_blank?, :blank?
  def blank?
    !nil? && orig_blank?  # `!nil?` will record a nil check.
  end
end
#endregion

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

describe NotificationsController, type: :controller do
  include DseHelpers

  describe "#index" do
    it "runs" do
      sym_params = {page: 1, per_page: 100}.freeze
      run_test :index, sym_params
    end
  end
end
#endregion
