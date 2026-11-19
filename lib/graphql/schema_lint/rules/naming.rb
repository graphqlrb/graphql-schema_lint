# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class NamingConvention < BuiltinRule
        metadata "naming-convention", :naming, :error, "Use consistent names for schema definitions."

        {
          types: "PascalCase", fields: "camelCase", arguments: "camelCase", input_fields: "camelCase",
          enum_values: "UPPER_CASE", directives: "camelCase", object_types: nil, interface_types: nil,
          union_types: nil, enum_types: nil, input_object_types: nil, scalar_types: nil
        }.each do |target, style|
          default = style ? {"style" => style} : {}
          option target, type: :hash, default:
        end

        message :violation, "%{coordinate} does not satisfy the naming convention."
        suggestion :violation, "Choose a name such as `%{replacement}`."
        suggestion :configured, "Choose a name that matches the configured convention for this element."
        message :configured, "%{coordinate} does not satisfy the naming convention."

        on_elements

        def self.resolve_options(settings)
          super.to_h do |target, rules|
            [target, LintCore::Naming.validate(rules)]
          rescue LintCore::InputError => error
            raise LintCore::InputError, "rules.#{id}.options.#{target}: #{error.message}"
          end
        end

        private

        def check(member, event)
          keys = target_keys(member, event).map(&:to_sym).reject { |key| key == :root_fields }
          rules = keys.reduce({}) { |combined, key| combined.merge(options.fetch(key)) }
          return if LintCore::Naming.valid?(member.name, rules)

          replacement = LintCore::Naming.replacement(member.name, rules)
          if replacement != member.name && LintCore::Naming.valid?(replacement, rules)
            violation(member, location: :name, replacement:)
          else
            violation(member, :configured, location: :name)
          end
        end
      end

      class NoTypenamePrefix < BuiltinRule
        metadata "no-typename-prefix", :naming, :warning, "Avoid repeating a type name at the start of its fields."
        option :case_sensitive, type: :boolean, default: false
        option :include_input_objects, type: :boolean, default: false
        option :ignore, type: :coordinate_patterns, default: []
        message :violation, "%{coordinate} repeats its type name at the start of the field name."
        suggestion :violation, "Remove the type name prefix and use a name such as `%{replacement}`."

        on_elements :field, :input_field

        private

        def check(field, event)
          return if event == :input_field && !options[:include_input_objects]
          return if collection_matches?(options[:ignore], field.coordinate)

          name = field.name
          prefix = field.owner.name
          matches = options[:case_sensitive] ? name.start_with?(prefix) : name.downcase.start_with?(prefix.downcase)
          return unless matches

          suffix = name[prefix.length..]
          replacement = suffix.empty? ? "name" : LintCore::Naming.convert(suffix, "camelCase")
          violation(field, location: :name, replacement:)
        end
      end
    end
  end
end
