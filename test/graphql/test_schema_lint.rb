# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "stringio"
require "tmpdir"
require "tempfile"
require "graphql/schema_lint"
require "graphql/schema_lint/test_helper"

class TestSchemaLint < Minitest::Test
  include GraphQL::SchemaLint::TestHelper

  class MutationResultRule < GraphQL::SchemaLint::Rule
    id "acme/mutation-result"
    default_severity :error
    option :field_name, type: :string, default: "message"
    message :missing, "%{coordinate} must return a message."

    def on_field(field)
      return unless field.root_kind == :mutation

      payload = field.type.named_type_info
      return unless payload&.kind == :object
      return if payload.field(options[:field_name])

      report(field, :missing)
    end
  end
  CASES = Psych.safe_load_file(File.expand_path("../../examples/schema_rules.yml", __dir__)).freeze

  CASES.each do |rule, example|
    define_method("test_#{rule.tr("-", "_")}") do
      assert_respond_to GraphQL::SchemaLint, :run
      config = {"rules" => {rule => {"options" => example.fetch("options")}}}

      rejected = run_sdl(example.fetch("invalid"), config)
      assert_operator rejected.exit_status, :<, 2, rejected.diagnostics.map(&:message).join("\n")
      assert_equal example.fetch("coordinates"), rejected.reportable.map(&:coordinate)
      assert rejected.reportable.all? { |diagnostic| diagnostic.rule_id == rule }

      accepted = run_sdl(example.fetch("valid"), config)
      assert_equal 0, accepted.exit_status
      assert_empty accepted.reportable
    end
  end

  def test_report_naming_error_at_the_name
    result = run_sdl(<<~GRAPHQL, "rules" => {"naming-convention" => "error"})
      """The query."""
      type Query { bad_name: ID }
    GRAPHQL
    diagnostic = result.reportable.fetch(0)
    assert_equal ["Query.bad_name", 2, 14], [diagnostic.coordinate, diagnostic.location.line, diagnostic.location.column]
  end

  def test_comment_suppresses_the_next_definition
    result = run_sdl(<<~GRAPHQL, "rules" => {"naming-convention" => "error"})
      type Query {
        # graphql-lint-disable-next-line naming-convention -- Existing API.
        bad_name: ID
      }
    GRAPHQL
    assert_equal 0, result.exit_status
    assert_equal :comment, result.diagnostics.fetch(0).suppressed_by
  end

  def test_nested_option_errors_are_configuration_errors
    result = run_sdl("type Query { goodName: ID }", "rules" => {
      "naming-convention" => {"options" => {"types" => {"style" => "guessed_case"}}}
    })
    assert_equal 2, result.exit_status
    assert_match(/style/, result.diagnostics.fetch(0).message)
  end

  def test_unknown_description_target_is_a_configuration_error
    result = run_sdl("type Query { id: ID }", "rules" => {
      "require-description" => {"options" => {"targets" => ["root_field"]}}
    })
    assert_equal 2, result.exit_status
    assert_match(/targets/, result.diagnostics.fetch(0).message)
  end

  def test_naming_templates_can_be_disabled
    rules = {
      "mutation-payload-type" => {"options" => {"naming" => nil}},
      "mutation-input-argument" => {"options" => {"type_naming" => nil}}
    }
    result = run_sdl(<<~GRAPHQL, "extends" => ["mutation-payload"], "rules" => rules)
      type Query { id: ID }
      type Mutation { cancel(input: Details!): Ack }
      input Details { id: ID }
      type Ack { ok: Boolean }
    GRAPHQL
    assert_equal 0, result.exit_status, result.reportable.map(&:message).join("\n")
    assert_empty result.reportable
  end

  def test_alphabetize_handles_group_order
    result = run_sdl("type Query { id: ID a: String }", "rules" => {
      "alphabetize" => {"options" => {"groups" => ["id", "*"]}}
    })
    assert_empty result.reportable
  end

  def test_a_deprecation_date_equal_to_today_is_not_overdue
    result = run_sdl('type Query { old: ID @deprecated(reason: "Remove 2026-11-18") }',
      "rules" => {"require-deprecation-date" => true})
    assert_empty result.reportable
  end

  def test_unavailable_directives_warn_once
    requirement = {"directive" => "unknown", "action" => "require", "targets" => ["Query.*"]}
    result = run_sdl("type Query { a: ID b: ID }", "rules" => {
      "directive-usage" => {"options" => {"requirements" => [requirement, requirement]}}
    })
    assert_equal 0, result.exit_status
    assert_equal ["warning"], result.reportable.map { |diagnostic| diagnostic.severity.to_s }
  end

  def test_required_description_diagnostic
    result = run_sdl("type Query { id: ID }", "rules" => {"require-description" => true})
    diagnostic = result.reportable.fetch(0)
    assert_equal "Query has no description.", diagnostic.message
    assert_equal "Add a GraphQL description before the definition.", diagnostic.suggestion
  end

  def test_cli_reports_a_positional_schema_and_writes_two_formats
    root = File.expand_path("../..", __dir__)
    executable = File.join(root, "exe/graphql-schema-lint")
    Dir.mktmpdir("schema-lint-cli") do |path|
      File.write("#{path}/schema.graphql", 'type Query { bad_name: ID }')
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), executable, "check", "schema.graphql",
        "--only", "naming-convention", "--format", "json", "--format", "sarif:annotations.sarif", chdir: path)

      assert_equal 1, status.exitstatus, stderr
      diagnostic = JSON.parse(stdout).fetch("diagnostics").fetch(0)
      assert_equal "Query.bad_name", diagnostic.fetch("coordinate")
      sarif = JSON.parse(File.read("#{path}/annotations.sarif"))
      assert_equal "naming-convention", sarif.fetch("runs").first.fetch("results").first.fetch("ruleId")
    end
  end

  def test_cli_renders_configuration_errors_as_json
    output, errors = StringIO.new, StringIO.new
    Dir.mktmpdir do |directory|
      config = File.join(directory, "invalid.yml")
      File.write(config, "version: 1\nunknown: true\n")
      status = GraphQL::SchemaLint::CLI.run(["check", "--config", config, "--format", "json"], stdout: output, stderr: errors)
      assert_equal 2, status
      assert_equal "core/config-error", JSON.parse(output.string).dig("diagnostics", 0, "rule")
      assert_includes errors.string, "Unknown setting"
    end
  end

  def test_introspection_reports_source_limitations_once
    schema = GraphQL::Schema.from_definition("type Query { id: ID }")
    Tempfile.create(["schema-lint", ".json"]) do |file|
      file.write(JSON.generate(schema.as_json))
      file.flush
      settings = {
        extends: [], schema: {sources: ["introspection:#{file.path}"]},
        rules: {"description-style" => true}
      }
      result = GraphQL::SchemaLint.run(config: settings)

      assert_equal ["core/limited-input"], result.reportable.map(&:rule_id)
      assert_match(/description-style/, result.reportable.first.message)
      assert_match(/directive/i, result.reportable.first.message)
    end
  end

  def test_skips_source_only_rules_on_a_ruby_schema
    schema = GraphQL::Schema.from_definition('"Find a user." type Query { id: ID }')
    result = GraphQL::SchemaLint.run(config: {
      extends: [], schema: {sources: [schema]},
      rules: {"description-style" => true, "no-hashtag-description" => true}
    })

    assert_equal 0, result.exit_status, result.reportable.map(&:message).join("\n")
    assert_equal ["core/limited-input"], result.reportable.map(&:rule_id)
    assert_match(/description-style/, result.reportable.first.message)
  end

  def test_custom_rule_can_access_referenced_types
    assert_diagnostics(rule: MutationResultRule, sdl: <<~GRAPHQL, expected: [{coordinate: "Mutation.cancel", message_key: :missing}])
      type Query { id: ID }
      type Mutation { cancel: Result }
      type Result { ok: Boolean }
    GRAPHQL
  end

  def test_type_diagnostic_lists_extension_definitions_as_related
    in_fixture = <<~GRAPHQL
      type Query { id: ID }
      extend type Query { name: String }
    GRAPHQL
    result = run_sdl(in_fixture, "rules" => {"require-description" => true})

    locations = result.reportable.first.related.map { |item| item.fetch(:location).line }
    assert_equal [2], locations
  end

  def test_naming_type_options_extend_global_types
    options = {"types" => {"prefix" => "Api"}, "input_object_types" => {"suffix" => "Input"}}
    result = run_sdl(<<~GRAPHQL, "rules" => {"naming-convention" => {"options" => options}})
      schema { query: ApiQuery }
      type ApiQuery { user(input: ApiUser): String }
      input ApiUser { email: String }
    GRAPHQL
    assert_equal ["ApiUser"], result.reportable.map(&:coordinate)
    assert_includes result.reportable.first.suggestion, "ApiUserInput"
  end

  def test_relay_preset_accepts_a_connection
    schema = <<~GRAPHQL
      type Query { users(first: Int, after: String): UserConnection }
      type UserConnection { edges: [UserEdge!]! pageInfo: PageInfo! }
      type UserEdge { cursor: String! node: User! }
      type User { id: ID! }
      type PageInfo { hasNextPage: Boolean! hasPreviousPage: Boolean! startCursor: String endCursor: String }
    GRAPHQL
    result = run_sdl(schema, "extends" => ["relay"])

    assert_equal 0, result.exit_status, result.reportable.map(&:message).join("\n")
    assert_empty result.reportable
  end

  def test_rule_inventory_has_all_examples
    assert_equal GraphQL::SchemaLint::BUILTINS.keys.sort, CASES.keys.sort
  end

  private

  def run_sdl(text, config)
    Tempfile.create(["schema", ".graphql"]) do |file|
      file.write(text)
      file.flush
      settings = {
        "version" => 1, "extends" => [], "today" => "2026-11-18",
        "schema" => {"sources" => [file.path]}
      }.merge(config)
      GraphQL::SchemaLint.run(config: settings)
    end
  end
end
