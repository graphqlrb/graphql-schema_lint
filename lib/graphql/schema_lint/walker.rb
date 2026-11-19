# frozen_string_literal: true

module GraphQL
  module SchemaLint
    class Walker
      def initialize(index)
        @index = index
        @types = index.types.values.sort_by(&:name)
        @directives = index.directives.values.sort_by(&:name)
      end

      def each_event
        yield :on_schema, @index
        @index.schema_directives.each { |app| yield :on_directive_application, app }

        @types.each do |type|
          next unless application_member?(type)

          yield :on_type, type
          yield :"on_#{type.kind}_type", type
          applications(type) { |app| yield :on_directive_application, app }
          type.fields.each_value do |field|
            next unless application_member?(field)

            yield :on_field, field
            applications(field) { |app| yield :on_directive_application, app }
            field.arguments.each_value do |arg|
              next unless application_member?(arg)

              yield :on_argument, arg
              applications(arg) { |app| yield :on_directive_application, app }
            end
          end
          type.input_fields.each_value do |field|
            next unless application_member?(field)

            yield :on_input_field, field
            applications(field) { |app| yield :on_directive_application, app }
          end
          type.values.each_value do |value|
            next unless application_member?(value)

            yield :on_enum_value, value
            applications(value) { |app| yield :on_directive_application, app }
          end
        end

        @directives.each do |directive|
          next unless application_member?(directive)

          yield :on_directive_definition, directive
          directive.arguments.each_value do |arg|
            next unless application_member?(arg)

            yield :on_argument, arg
            applications(arg) { |app| yield :on_directive_application, app }
          end
        end
      end

      private

      def applications(member, &block)
        member.directives.each(&block)
      end

      def application_member?(member)
        !(member.respond_to?(:builtin?) && member.builtin?) && !(member.respond_to?(:prelude?) && member.prelude?)
      end
    end
  end
end
