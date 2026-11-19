# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class MutationRule < BuiltinRule
        private

        def expected_type_name(field, template)
          template&.gsub("{FieldName}", LintCore::Naming.convert(field.name, "PascalCase"))
        end

        def mutation_fields
          name = @index.roots["mutation"]
          name ? @index.types.fetch(name).fields.values : []
        end
      end

      class MutationPayloadType < MutationRule
        metadata "mutation-payload-type", :mutation, :error, "Return a dedicated payload from each mutation."
        option :allowed_kinds, type: :string_list, default: ["object"], values: OUTPUT_KINDS
        option :allow_list, type: :boolean, default: false
        option :naming, type: :string, default: "{FieldName}Payload", nullable: true
        option :unique, type: :boolean, default: true
        option :nullability, type: :enum, default: "any", values: %w[any nullable non_null]
        message :kind, "%{coordinate} returns a type that is not an allowed mutation payload."
        suggestion :kind, "Return a dedicated payload such as `%{expected}`."
        message :list, "%{coordinate} returns a list instead of a single payload."
        suggestion :list, "Place the list inside a dedicated payload type."
        message :name, "%{coordinate} returns a payload with an unexpected name."
        suggestion :name, "Name the payload type `%{expected}`."
        message :shared, "%{coordinate} shares its payload type with another mutation."
        suggestion :shared, "Give each mutation its own payload type."
        message :nullability, "%{coordinate} must return a %{mode} payload."
        suggestion :nullability, "Change the payload's outer nullability."

        def setup(context)
          super
          @usage = mutation_fields.map { |field| field.type.named }.tally
        end

        def on_field(field)
          return unless field.root_kind == :mutation

          output = field.type
          payload = @index.types[output.named]
          expected = expected_type_name(field, options[:naming])
          unless payload && options[:allowed_kinds].include?(payload.kind.to_s)
            violation(field, :kind, expected: expected || expected_type_name(field, "{FieldName}Payload"))
            return
          end
          violation(field, :list) if output.list? && !options[:allow_list]
          violation(field, :name, expected:) if expected && output.named != expected
          violation(field, :shared) if options[:unique] && @usage.fetch(output.named) > 1
          mode = options[:nullability]
          if mode != "any" && output.non_null? != (mode == "non_null")
            violation(field, :nullability, mode:)
          end
        end
      end

      class MutationInputArgument < MutationRule
        metadata "mutation-input-argument", :mutation, :error, "Group mutation arguments in a dedicated input object."
        option :argument_name, type: :string, default: "input"
        option :type_naming, type: :string, default: "{FieldName}Input", nullable: true
        option :require_non_null, type: :boolean, default: true
        option :allow_no_arguments, type: :boolean, default: true
        option :additional_arguments, type: :string_list, default: []
        message :violation, "%{coordinate} does not group arguments in the required input object."
        suggestion :violation, "Use `%{argument}: %{expected}` and keep only permitted additional arguments."

        def on_field(field)
          return unless field.root_kind == :mutation
          return if field.arguments.empty? && options[:allow_no_arguments]

          name = options[:argument_name]
          input = field.arguments[name]
          expected = expected_type_name(field, options[:type_naming])
          extra_arguments = field.arguments.keys - [name] - options[:additional_arguments]
          return if extra_arguments.empty? && valid_input?(input, expected)

          input_name = expected || (input.type.named if input && @index.types[input.type.named]&.kind == :input_object)
          input_name ||= expected_type_name(field, "{FieldName}Input")
          input_name = "#{input_name}!" if options[:require_non_null]
          violation(field, argument: name, expected: input_name)
        end

        private

        def valid_input?(input, expected)
          return false unless input

          ref = input.type
          @index.types[ref.named]&.kind == :input_object && !ref.list? &&
            (expected.nil? || ref.named == expected) && (!options[:require_non_null] || ref.non_null?)
        end
      end

      class MutationPayloadFields < MutationRule
        metadata "mutation-payload-fields", :mutation, :error, "Require or prohibit fields on mutation payloads."
        option :required_fields, type: :array, default: []
        option :require_query_field, type: :boolean, default: false
        option :forbidden_fields, type: :string_list, default: []
        fingerprint_keys :field
        message :required, "%{coordinate} does not expose the expected `%{field}` field."
        suggestion :required, "Add `%{signature}` to the payload."
        message :query, "%{coordinate} does not expose a field returning the query root."
        suggestion :query, "Add a field returning `%{query_type}`."
        message :forbidden, "%{coordinate} exposes the forbidden field `%{field}`."
        suggestion :forbidden, "Remove `%{field}` from the payload."

        def self.resolve_options(settings)
          options = super
          unless options[:required_fields].all? { |item| required_field?(item) }
            raise LintCore::InputError, "mutation-payload-fields.required_fields must contain name/type mappings."
          end

          options
        end

        def self.required_field?(item)
          return false unless item.is_a?(Hash)

          item = item.transform_keys(&:to_s)
          (item.keys - %w[name type]).empty? && item["name"].is_a?(String) &&
            (!item.key?("type") || item["type"].is_a?(String))
        end
        private_class_method :required_field?

        def on_schema(index)
          mutation_fields.map { |field| field.type.named }.uniq.each do |name|
            payload = index.types[name]
            check_payload(payload) if payload&.kind == :object && !payload.prelude?
          end
        end

        private

        def check_payload(payload)
          options[:required_fields].each do |entry|
            name = value(entry, :name)
            expected_type = value(entry, :type)
            present = payload.fields[name]
            next if present && (expected_type.nil? || present.type.to_s == expected_type)

            signature = expected_type ? "#{name}: #{expected_type}" : name
            violation(payload, :required, field: name, signature:, data: {field: name})
          end

          query_type = @index.roots["query"]
          if options[:require_query_field] && payload.fields.values.none? { |field| field.type.named == query_type && !field.type.list? }
            violation(payload, :query, query_type:)
          end

          (options[:forbidden_fields] & payload.fields.keys).each do |name|
            violation(payload, :forbidden, field: name, data: {field: name})
          end
        end
      end
    end
  end
end
