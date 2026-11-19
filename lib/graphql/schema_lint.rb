# frozen_string_literal: true

require "graphql/lint_core"
require "date"
require "psych"
require_relative "schema_lint/version"
require_relative "schema_lint/rule"
require_relative "schema_lint/walker"
require_relative "schema_lint/runner"
require_relative "schema_lint/cli"

module GraphQL
  module SchemaLint
    TOOL = "graphql-schema_lint"
    CONFIG_FILE = ".graphql-schema-lint.yml"
    PACKAGE = File.expand_path("../..", __dir__)
    DEFAULTS = {
      "extends" => ["recommended"], "today" => nil, "emit_generated_sdl" => nil,
      "schema" => {"sources" => ["schema.graphql"], "prelude" => [], "skip_checks" => []}
    }.freeze

    # @api public
    def self.register_rule(rule)
      raise LintCore::InputError, "Expected a SchemaLint::Rule subclass." unless rule.is_a?(Class) && rule < Rule
      unless rule.id&.match?(/\A[a-z0-9-]+\/[a-z0-9-]+\z/)
        raise LintCore::InputError, "Custom schema rule IDs must use a namespace/name."
      end

      @registration_lock.synchronize do
        raise LintCore::InputError, "Duplicate schema rule: #{rule.id}" if @custom_rules.key?(rule.id)

        @custom_rules[rule.id] = rule
      end
    end

    # @api public
    def self.rules
      @registration_lock.synchronize { BUILTINS.merge(@custom_rules).freeze }
    end

    # @api public
    def self.run(config: nil, overrides: {})
      Runner.new.run(config:, overrides:)
    end

    def self.examples(rule_id)
      example = Psych.safe_load_file(File.join(PACKAGE, "examples/schema_rules.yml"))[rule_id]
      example&.slice("invalid", "valid")
    end

    @registration_lock = Mutex.new
    @custom_rules = {}

    Dir[File.join(__dir__, "schema_lint/rules/*.rb")].sort.each { |file| require file }
    BUILTINS = Rules.constants(false).map { |name| Rules.const_get(name) }
      .select { |rule| rule.is_a?(Class) && rule < BuiltinRule && rule.id }
      .to_h { |rule| [rule.id, rule] }.freeze
    PRESETS = Dir[File.join(PACKAGE, "presets/*.yml")].to_h do |file|
      [File.basename(file, ".yml"), Psych.safe_load_file(file)]
    end.freeze
  end
end
