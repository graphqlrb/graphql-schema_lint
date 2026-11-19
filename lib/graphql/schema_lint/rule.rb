# frozen_string_literal: true

module GraphQL
  module SchemaLint
    # @api public
    class Rule < LintCore::Rule
      EVENTS = %i[schema type object_type interface_type union_type enum_type input_object_type scalar_type
        field argument input_field enum_value directive_definition directive_application].freeze

      EVENTS.each { |event| define_method(:"on_#{event}") { |_| } }

      # @api public
      def report(member, key, related: [], subject: nil, **arguments)
        if member.is_a?(LintCore::TypeInfo)
          related += member.extension_locations.map { |location| {location:, message: "Type extension"} }
        elsif member.is_a?(LintCore::DirectiveApplication)
          subject ||= {kind: "directive_application", target: member.target.coordinate, directive: member.name, index: member.index}
        end
        super(member, key, related:, subject:, **arguments)
      end

      def self.requires_source_text(value = nil)
        return @requires_source_text unless value

        @requires_source_text = value
      end
    end

    class BuiltinRule < Rule
      OUTPUT_KINDS = %w[object interface union enum scalar].freeze
      TARGETS = %w[types object_types interface_types union_types enum_types input_object_types scalar_types
        fields root_fields arguments input_fields enum_values directives].freeze

      def self.on_elements(*events, method: :check)
        events = %i[type field argument input_field enum_value directive_definition] if events.empty?
        events.each do |event|
          define_method(:"on_#{event}") { |member| send(method, member, event) }
        end
      end

      def self.metadata(id_value, category_value, severity, explanation)
        id id_value
        category category_value
        default_severity severity
        description explanation
      end

      def self.resolve_options(settings)
        resolved = super
        options.each do |name, metadata|
          choices = metadata[:values]
          next unless metadata[:type] == :string_list && choices

          unexpected = resolved.fetch(name) - choices
          unless unexpected.empty?
            raise LintCore::InputError, "Invalid rules.#{id}.options.#{name}: #{unexpected.join(", ")}"
          end
        end
        resolved
      end

      def setup(context)
        super
        @coordinate_patterns = {}
        @index = context.fetch(:index)
        @settings = context.fetch(:config)
        @sources = context.fetch(:sources)
        @rule_options = context.fetch(:rule_options)
      end

      private

      def collection_matches?(patterns, value)
        Array(patterns).any? do |pattern|
          pattern = (@coordinate_patterns[pattern] ||= LintCore::CoordinatePattern.new(pattern)) if pattern.is_a?(String)
          pattern.match?(value)
        end
      end

      def target_keys(member, event)
        case event
        when :type
          ["types", event_key(member.kind)]
        when :field
          member.root_kind ? %w[fields root_fields] : %w[fields]
        when :directive_definition
          %w[directives]
        else
          [event_key(event)]
        end
      end

      def event_key(kind)
        kind = :"#{kind}_type" if %i[object interface union enum input_object scalar].include?(kind)
        "#{kind}s"
      end

      def targets?(member, event, targets = options[:targets])
        targets.nil? || !(targets & target_keys(member, event)).empty?
      end

      def value(hash, key, default = nil)
        hash.fetch(key) { hash.fetch(key.to_s, default) }
      end

      def violation(member, key = :violation, **attributes)
        report(member, key, **{coordinate: member&.coordinate}.merge(attributes))
      end

      def subject_blank?(text)
        text.nil? || /\A[[:space:]]*\z/.match?(text)
      end
    end

    module Rules
    end
  end
end
