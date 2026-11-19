# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class StrictIdInTypes < BuiltinRule
        metadata "strict-id-in-types", :relationships, :warning, "Require exactly one identifier on applicable object types."
        option :accepted_names, type: :string_list, default: ["id"]
        option :accepted_types, type: :string_list, default: ["ID!"]
        option :exclude_suffixes, type: :string_list, default: %w[Payload Connection Edge]
        option :exclude, type: :coordinate_patterns, default: ["PageInfo"]
        message :violation, "%{coordinate} has %{count} matching identifiers and must have exactly one."
        suggestion :violation, "Keep one identifier with an accepted name and type."

        def on_object_type(type)
          return if type.root_kind || type.name.end_with?(*options[:exclude_suffixes])
          return if collection_matches?(options[:exclude], type.coordinate)

          count = type.fields.values.count do |field|
            options[:accepted_names].include?(field.name) && options[:accepted_types].include?(field.type.to_s)
          end
          violation(type, count:) unless count == 1
        end
      end

      class NoUnreachableTypes < BuiltinRule
        metadata "no-unreachable-types", :structure, :warning, "Detect schema types that clients cannot reach."
        option :ignore, type: :coordinate_patterns, default: []
        option :check_directives, type: :boolean, default: false
        message :violation, "%{coordinate} is unreachable from the schema roots."
        suggestion :violation, "Remove it or expose it from a reachable part of the schema."
        message :unused, "%{coordinate} is defined but is not applied in the schema."
        suggestion :unused, "Remove the directive definition or use it on the intended schema element."

        def setup(context)
          super
          @used_directives = {}
        end

        def on_type(type)
          return if type.reachable? || collection_matches?(options[:ignore], type.coordinate)

          violation(type)
        end

        def on_directive_application(directive)
          @used_directives[directive.name] = true
        end

        def finish
          return unless options[:check_directives]

          @index.directives.each_value do |directive|
            next if directive.builtin? || directive.prelude? || @used_directives[directive.name]
            next if collection_matches?(options[:ignore], directive.coordinate)

            violation(directive, :unused)
          end
        end
      end

      class Alphabetize < BuiltinRule
        SORTABLE = %w[fields input_fields enum_values arguments].freeze

        metadata "alphabetize", :structure, :warning, "Put schema definitions in a consistent order."
        option :targets, type: :string_list, default: SORTABLE, values: SORTABLE
        option :order, type: :enum, default: "alphabetical", values: %w[alphabetical lexicographical]
        option :groups, type: :string_list, default: []
        requires_source_text true
        message :violation, "%{coordinate} is out of order."
        suggestion :violation, "Use this order: %{order}."

        def on_type(type)
          check_order(type.fields, "fields")
          check_order(type.input_fields, "input_fields")
          check_order(type.values, "enum_values")
        end

        def on_field(field)
          check_order(field.arguments, "arguments")
        end
        alias_method :on_directive_definition, :on_field

        private

        def check_order(collection, target)
          return unless options[:targets].include?(target)

          current = collection.values.reject(&:prelude?)
          expected = current.each_with_index.sort_by do |member, offset|
            group = options[:groups].index { |pattern| collection_matches?([pattern], member.name) }
            name = options[:order] == "alphabetical" ? member.name.downcase : member.name
            [group || options[:groups].length, name, offset]
          end.map(&:first)
          incorrect = current.zip(expected).find { |actual, sorted| actual != sorted }
          return unless incorrect

          violation(incorrect.first, location: :name, order: expected.map(&:name).join(", "))
        end
      end

      class RootFieldNullability < BuiltinRule
        metadata "root-field-nullability", :structure, :warning, "Use consistent outer nullability on root fields."
        option :mode, type: :enum, default: "nullable", values: %w[nullable non_null]
        option :roots, type: :string_list, default: %w[query mutation], values: %w[query mutation subscription]
        message :violation, "%{coordinate} must have a %{mode} return type."
        suggestion :violation, "Change the return type to `%{type}`."

        def on_field(field)
          return unless options[:roots].include?(field.root_kind.to_s)

          mode = options[:mode]
          expected_non_null = mode == "non_null"
          return if field.type.non_null? == expected_non_null

          type = expected_non_null ? "#{field.type}!" : field.type.to_s.delete_suffix("!")
          violation(field, mode: mode.tr("_", "-"), type:)
        end
      end
    end
  end
end
