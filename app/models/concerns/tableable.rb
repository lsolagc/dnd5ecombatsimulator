require "active_support/concern"

module Tableable
  extend ActiveSupport::Concern

  class_methods do
    def table_columns
      Array.wrap(column_names - ignore_table_columns + default_columns).flatten
    end

    def humanized_table_columns
      table_columns.map { |column| column.humanize }
    end

    def ignore_table_columns
      column_names.select { |column| column == "id" || column.include?("_id") }
    end

    def default_columns
      [ "Actions" ]
    end
  end
end
