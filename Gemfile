# frozen_string_literal: true

source "https://rubygems.org"

gemspec

core = File.expand_path(ENV.fetch("GRAPHQL_LINT_CORE_PATH", "../graphql-lint_core"), __dir__)
if File.file?(File.join(core, "graphql-lint_core.gemspec"))
  path core do
    gem "graphql-lint_core"
  end
elsif ENV["DEPENDABOT"] == "true"
  gem "graphql-lint_core", git: "https://github.com/graphqlrb/graphql-lint_core.git",
    ref: "de4a0c1d2f042ea816a9dbd9570abb954c8f1efb"
end

gem "rake", "~> 13.0"
gem "minitest", ">= 5.20", "< 7"
