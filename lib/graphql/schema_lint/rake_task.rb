# frozen_string_literal: true

require "rake/tasklib"
require "graphql/schema_lint"

module GraphQL
  module SchemaLint
    # @api public
    class RakeTask < Rake::TaskLib
      attr_accessor :config

      def initialize(name = :schema_lint)
        yield self if block_given?

        desc "Lint the GraphQL schema"
        task name do
          args = ["check"]
          args.concat(["--config", config]) if config
          status = CLI.run(args)
          abort("GraphQL schema lint failed with status #{status}.") unless status.zero?
        end
      end
    end
  end
end
