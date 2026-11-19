# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class DeprecationRule < BuiltinRule
        DEFAULT_REASON = "No longer supported"
        on_elements :field, :argument, :input_field, :enum_value

        private

        def application(member)
          member.directives.find { |item| item.name == "deprecated" }
        end

        def reason(member)
          directive = application(member)
          return member.deprecation&.reason unless directive
          return DEFAULT_REASON unless directive.arguments.key?("reason")

          directive.arguments.fetch("reason").value
        end
      end

      class RequireDeprecationReason < DeprecationRule
        metadata "require-deprecation-reason", :deprecation, :error, "Explain why an API is deprecated."
        option :treat_default_reason_as_missing, type: :boolean, default: true
        message :violation, "%{coordinate} is deprecated without a reason."
        suggestion :violation, 'Add a reason such as @deprecated(reason: "Use `newField` instead.").'

        private

        def check(member, _event)
          return unless member.deprecation || application(member)

          text = reason(member)
          missing_default = options[:treat_default_reason_as_missing] && text == DEFAULT_REASON
          violation(member) if subject_blank?(text) || missing_default
        end
      end

      class DeprecationReasonFormat < DeprecationRule
        metadata "deprecation-reason-format", :deprecation, :warning, "Apply formatting and replacement-reference rules to deprecations."
        option :pattern, type: :regexp
        option :min_length, type: :integer
        option :require_replacement_reference, type: :boolean, default: false
        message :violation, "%{coordinate} has a deprecation reason that does not match the required format."
        suggestion :violation, "Rewrite the deprecation reason using the configured format."
        message :missing_replacement, "%{coordinate} has no valid replacement reference in its deprecation reason."
        suggestion :missing_replacement, "Reference an existing, supported element in backticks."

        private

        def check(member, _event)
          return unless member.deprecation || application(member)

          text = reason(member).to_s
          length = options[:min_length]
          pattern = options[:pattern]
          violation(member) if (length && text.length < length) || (pattern && !pattern.match?(text))
          return unless options[:require_replacement_reference]

          references = text.scan(/`([^`]+)`/).flatten
          if references.empty? || references.any? { |reference| !supported_replacement?(member, reference) }
            violation(member, :missing_replacement)
          end
        end

        def supported_replacement?(member, reference)
          element = if reference.match?(/[.@(]/)
            @index.find(reference)
          else
            parent = member.owner
            next_parent = parent.respond_to?(:owner) && parent.owner
            @index.find("#{parent.coordinate}.#{reference}") ||
              @index.find("#{parent.coordinate}(#{reference}:)") ||
              (next_parent && @index.find("#{next_parent.coordinate}.#{reference}")) ||
              @index.find(reference)
          end
          element && (!element.respond_to?(:deprecation) || element.deprecation.nil?)
        end
      end

      class RequireDeprecationDate < DeprecationRule
        metadata "require-deprecation-date", :deprecation, :warning, "Set and enforce a removal date for deprecated elements."
        option :source, type: :enum, default: "reason", values: %w[reason argument]
        option :pattern, type: :regexp, default: "(\\d{4}-\\d{2}-\\d{2})"
        option :argument, type: :string, default: "deletionDate"
        option :date_format, type: :string, default: "%Y-%m-%d"
        option :overdue, type: :enum, default: "error", values: %w[off info warning error]
        message :violation, "%{coordinate} is deprecated without a valid removal date."
        suggestion :violation, "Add a removal date in the configured date format."
        message :overdue, "%{coordinate} is overdue for removal as of %{date}."
        suggestion :overdue, "Remove the deprecated element or update its removal date."

        def setup(context)
          super
          @today = context.fetch(:today)
        end

        private

        def check(member, _event)
          return unless member.deprecation || application(member)

          date = date_for(member)
          if date.nil?
            violation(member)
          elsif date < @today && options[:overdue] != "off"
            violation(member, :overdue, severity: options[:overdue].to_sym, date: date.iso8601)
          end
        end

        def date_for(member)
          text = if options[:source] == "argument"
            application(member)&.arguments&.fetch(options[:argument], nil)&.value
          else
            match = options[:pattern].match(reason(member).to_s)
            match[1] if match && match.length > 1
          end
          return unless text.is_a?(String)

          format = options[:date_format]
          date = Date.strptime(text, format)
          date if date.strftime(format) == text
        rescue Date::Error
          nil
        end
      end
    end
  end
end
