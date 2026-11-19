# frozen_string_literal: true

require "graphql/schema_lint/test_helper"

module GraphQL
  module SchemaLint
    # @api public
    module RSpec
      def expect_diagnostics(rule:, sdl:, expected:, options: {})
        actual = TestHelper.collect(rule:, sdl:, expected:, options:)
        expect(actual).to eq(TestHelper.normalize(expected))
      end
    end
  end
end
