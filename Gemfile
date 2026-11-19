# frozen_string_literal: true

source "https://rubygems.org"

gemspec

core = File.expand_path(ENV.fetch("GRAPHQL_LINT_CORE_PATH", "../graphql-lint_core"), __dir__)
if File.file?(File.join(core, "graphql-lint_core.gemspec"))
  gem "graphql-lint_core", path: core
end

gem "rake", "~> 13.0"
gem "minitest", ">= 5.20", "< 7"
