# GraphQL Schema Lint

Check an SDL schema against your project's GraphQL naming, documentation, deprecation, and structure conventions.

## Install from this checkout

This gem is unreleased. Place a `graphql-lint_core` checkout beside this repository or set `GRAPHQL_LINT_CORE_PATH` to its location. Bundler uses RubyGems when a local Core checkout is unavailable.

```sh
bundle install
bundle exec ruby exe/graphql-schema-lint check schema.graphql
```

Save this example as `schema.graphql`. The command reports `Query.legacy_user` because fields normally use camelCase.

```graphql
"""The query root."""
type Query {
  legacy_user: ID
}
```

## Configure the rules

`graphql-schema-lint init` writes `.graphql-schema-lint.yml`. In a checkout, use the executable path from the example above. The default preset is `recommended`. Add `mutation-payload` or `relay` to adopt the corresponding structural conventions. Use `all` to try every rule.

```yaml
version: 1
extends: [recommended, mutation-payload]
schema:
  sources: ["schema/**/*.graphql"]
rules:
  require-description:
    options:
      targets: [types, root_fields]
  root-field-nullability: warning
```

Run `graphql-schema-lint rules` to list the rules and `graphql-schema-lint explain naming-convention` to see the naming options. Use `--format github`, `--format json`, or `--format sarif:lint.sarif` for CI. Exit statuses are 0 for success, 1 for a failing diagnostic, 2 for invalid input or configuration, and 3 for an internal error.

Use only trusted configuration and Ruby schema files. Configuration `require` entries and Ruby schema inputs can execute Ruby code. For date-based deprecation rules, set `today` in the configuration or set `GRAPHQL_LINT_TODAY` to an ISO 8601 date for repeatable CI results.

## Ruby

```ruby
require "graphql/schema_lint"

result = GraphQL::SchemaLint.run(config: ".graphql-schema-lint.yml")
result.reportable.each { |diagnostic| puts diagnostic.message }
exit result.exit_status
```

For Rake integration, load `graphql/schema_lint/rake_task` and declare `GraphQL::SchemaLint::RakeTask.new`.

## Development

Run `bundle exec rake test build` at this repository's root. This gem has its
own version and accepts Core 0.1.x. Before Core is published, GitHub CI can
use a public Core checkout named by the `GRAPHQL_LINT_CORE_REPOSITORY`
repository variable (`owner/repository`). The release workflow resolves Core
from RubyGems.

MIT license.
