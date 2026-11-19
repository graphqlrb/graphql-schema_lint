# frozen_string_literal: true

require "fileutils"
require "json"
require "psych"
require "graphql/schema_lint"

path = File.expand_path("../docs/rules.md", __dir__)
lines = ["# Schema lint rules", "", "Run `graphql-schema-lint rules` to see which presets enable each rule.", ""]

GraphQL::SchemaLint.rules.sort.each do |id, rule|
  lines.concat(["## `#{id}`", "", rule.description, "", "Default severity `#{rule.default_severity}`.", ""])
  if rule.options.any?
    lines.concat(["### Options", ""])
    rule.options.each do |name, option|
      details = ["Type `#{option.fetch(:type)}`.", "Default `#{JSON.generate(option[:default])}`."]
      details << "Values #{option[:values].map { |value| "`#{value}`" }.join(", ")}." if option[:values]
      details << option[:description] if option[:description]
      lines << "- `#{name}`. #{details.join(" ")}"
    end
    lines << ""
  end

  examples = GraphQL::SchemaLint.examples(id) || {}
  options = examples.fetch("options", {})
  unless options.empty?
    config = { "rules" => { id => { "options" => options } } }
    lines.concat(["### Options used in the examples", "", "```yaml", Psych.dump(config).delete_prefix("---\n").chomp, "```", ""])
  end
  examples.slice("invalid", "valid").each do |label, sdl|
    lines.concat(["### #{label.capitalize} example", "", "```graphql", sdl.chomp, "```", ""])
  end
end

content = lines.join("\n")
if ARGV.include?("--check")
  abort("docs/rules.md is outdated. Run bundle exec rake docs:generate.") unless
    File.file?(path) && File.read(path, encoding: "UTF-8").gsub("\r\n", "\n") == content
else
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content, encoding: "UTF-8")
end
