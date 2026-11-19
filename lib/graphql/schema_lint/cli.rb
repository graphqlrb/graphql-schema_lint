# frozen_string_literal: true

module GraphQL
  module SchemaLint
    class CLI
      # @api public
      def self.run(argv, stdout: $stdout, stderr: $stderr)
        LintCore::CLI.run(SchemaLint, argv, name: "graphql-schema-lint", defaults: DEFAULTS, presets: PRESETS,
          options: method(:schema_options), stdout:, stderr:)
      end

      def self.schema_options(parser, overrides, _arguments)
        sources = []
        parser.on("--schema SOURCE", "Read a schema source") { |source| sources << source }
        parser.on("--emit-generated-sdl PATH", "Write generated SDL with source positions") do |path|
          overrides["emit_generated_sdl"] = path
        end
        lambda do |arguments|
          sources.concat(arguments)
          overrides["schema"] = {"sources" => sources} unless sources.empty?
          arguments.clear
        end
      end
      private_class_method :schema_options
    end
  end
end
