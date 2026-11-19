# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class DirectiveUsage < BuiltinRule
        metadata "directive-usage", :custom, :error, "Apply project-specific schema directive requirements."
        option :requirements, type: :array, default: []
        fingerprint_keys :directive, :requirement
        message :required, "%{coordinate} must have a valid @%{directive} directive."
        suggestion :required, "Add @%{directive} with the configured arguments."
        message :forbidden, "%{coordinate} must not use @%{directive}."
        suggestion :forbidden, "Remove @%{directive}."
        message :unknown, "The schema does not define @%{directive}; its directive requirement was skipped."
        suggestion :unknown, "Check the directive name and include its definition with the schema."
        message :custom, "%{text}"
        suggestion :custom, "Update the schema element to match the directive requirement."

        on_elements

        def self.resolve_options(settings)
          options = super
          requirements = options[:requirements].map.with_index do |requirement, index|
            normalize_requirement(requirement, index)
          end
          options.merge(requirements:)
        end

        def self.normalize_requirement(requirement, index)
          requirement = requirement.transform_keys(&:to_s) if requirement.is_a?(Hash)
          path = "directive-usage.requirements[#{index}]"
          unless requirement.is_a?(Hash) && (requirement.keys - %w[directive action kinds targets arguments message]).empty? &&
              requirement["directive"].is_a?(String) && %w[require forbid].include?(requirement["action"])
            raise LintCore::InputError, "#{path} must specify a directive and a require or forbid action."
          end

          %w[kinds targets].each do |key|
            list = requirement.fetch(key, [])
            unless list.is_a?(Array) && list.all?(String)
              raise LintCore::InputError, "#{path}.#{key} must be a list of strings."
            end
          end

          patterns = requirement.fetch("arguments", {})
          unless patterns.is_a?(Hash) && patterns.values.all?(String)
            raise LintCore::InputError, "#{path}.arguments must be a mapping of regular expressions."
          end
          if requirement.key?("message") && !requirement["message"].is_a?(String)
            raise LintCore::InputError, "#{path}.message must be a string."
          end
          patterns = patterns.transform_keys(&:to_s).transform_values { |pattern| Regexp.new(pattern, timeout: 1.0) }
          requirement.merge("arguments" => patterns)
        rescue RegexpError => error
          raise LintCore::InputError, "Invalid regular expression in #{path}.arguments: #{error.message}"
        end
        private_class_method :normalize_requirement

        def on_schema(index)
          @requirements = options[:requirements].each_with_index.select do |requirement, _offset|
            index.directives.key?(requirement.fetch("directive"))
          end

          unknown = options[:requirements].map { |requirement| requirement.fetch("directive") }.uniq - index.directives.keys
          unknown.each do |directive|
            violation(nil, :unknown, directive:, severity: :warning, data: {directive:})
          end
        end

        private

        def check(member, event)
          return unless member.respond_to?(:directives)

          kind = event == :type ? "#{member.kind}_type" : event.to_s
          @requirements.each do |requirement, offset|
            kinds = requirement.fetch("kinds", [])
            targets = requirement.fetch("targets", [])
            next unless kinds.empty? || kinds.include?(kind)
            next unless targets.empty? || collection_matches?(targets, member.coordinate)

            check_requirement(requirement, member, offset)
          end
        end

        def check_requirement(requirement, member, offset)
          name = requirement.fetch("directive")
          applications = member.directives.select { |directive| directive.name == name }
          required = requirement.fetch("action") == "require"
          violates = if required
            applications.none? { |directive| valid_arguments?(directive, requirement.fetch("arguments")) }
          else
            !applications.empty?
          end
          return unless violates

          text = requirement["message"]
          key = text ? :custom : (required ? :required : :forbidden)
          violation(member, key, directive: name, text:, data: {directive: name, requirement: offset})
        end

        def valid_arguments?(directive, patterns)
          patterns.all? do |name, pattern|
            argument = directive.arguments[name]
            argument && pattern.match?(argument.value.is_a?(String) ? argument.value : argument.literal)
          end
        end
      end
    end
  end
end
