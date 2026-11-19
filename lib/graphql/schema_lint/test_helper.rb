# frozen_string_literal: true

require "tempfile"
require "graphql/schema_lint"

module GraphQL
  module SchemaLint
    # @api public
    module TestHelper
      def assert_diagnostics(rule:, sdl:, expected:, options: {})
        actual = TestHelper.collect(rule:, sdl:, expected:, options:)
        assert_equal TestHelper.normalize(expected), actual
      end

      def self.collect(rule:, sdl:, expected:, options:)
        id = rule.is_a?(String) ? rule : rule.id
        SchemaLint.register_rule(rule) if !rule.is_a?(String) && SchemaLint.rules[id] != rule
        Tempfile.create(["schema-lint", ".graphql"]) do |file|
          file.write(sdl)
          file.flush
          result = SchemaLint.run(config: {
            version: 1, extends: [], schema: {sources: [file.path]}, rules: {id => {options:}}
          })
          diagnostics = result.diagnostics
          failed = diagnostics.find { |item| item.fatal? || item.rule_id.start_with?("core/") && item.severity == :error }
          raise ArgumentError, failed.message if failed

          keys = normalize(expected).flat_map(&:keys).uniq
          diagnostics.select { |item| item.rule_id == id }.map do |item|
            keys.to_h { |key| [key, item.public_send(key).to_s] }
          end
        end
      end

      def self.normalize(expected)
        expected.map { |item| item.transform_keys(&:to_sym).transform_values(&:to_s) }
      end
    end
  end
end
