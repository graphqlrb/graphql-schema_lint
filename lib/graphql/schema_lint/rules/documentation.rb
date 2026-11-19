# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class RequireDescription < BuiltinRule
        metadata "require-description", :documentation, :warning, "Require descriptions for selected schema elements."
        option :targets, type: :string_list, default: ["types"], values: TARGETS
        option :ignore_relay_types, type: :boolean, default: false
        option :ignore, type: :coordinate_patterns, default: []
        message :violation, "%{coordinate} has no description."
        suggestion :violation, 'Add a GraphQL description before the definition.'
        on_elements

        private

        def check(member, event)
          return unless member.description.nil? && targets?(member, event)
          return if collection_matches?(options[:ignore], member.coordinate)
          if options[:ignore_relay_types]
            type_name = member.coordinate.split(/[.(]/, 2).first
            return if type_name == "PageInfo" || type_name.end_with?("Connection", "Edge")
          end

          violation(member)
        end
      end

      class NoEmptyDescription < BuiltinRule
        metadata "no-empty-description", :documentation, :error, "Reject empty schema descriptions."
        message :violation, "%{coordinate} has an empty description."
        suggestion :violation, "Explain what this element represents or remove the empty description."
        on_elements

        private

        def check(member, _event)
          violation(member) if member.description && subject_blank?(member.description)
        end
      end

      class DescriptionStyle < BuiltinRule
        metadata "description-style", :documentation, :warning, "Use one string style for SDL descriptions."
        option :style, type: :enum, default: "block", values: %w[block inline]
        requires_source_text true
        message :violation, "%{coordinate} uses the wrong description string style."
        suggestion :violation, "Write the description as a %{style} string."
        on_elements

        private

        def check(member, _event)
          style = member.description_style
          violation(member, style: options[:style]) if style && style.to_s != options[:style]
        end
      end

      class DescriptionFormat < BuiltinRule
        metadata "description-format", :documentation, :warning, "Apply formatting requirements to descriptions."
        option :capitalized, type: :boolean, default: true
        option :end_with_period, type: :boolean, default: false
        option :max_length, type: :integer
        option :forbidden_patterns, type: :string_list, default: []
        option :targets, type: :string_list, default: TARGETS, values: TARGETS
        message :capitalized, "%{coordinate} starts its description with a lowercase letter."
        suggestion :capitalized, "Capitalize the first letter."
        message :end_with_period, "%{coordinate} has a description that does not end with a period."
        suggestion :end_with_period, "End the description with a period."
        message :max_length, "%{coordinate} has a description longer than %{max} characters."
        suggestion :max_length, "Shorten the description."
        message :forbidden_pattern, "%{coordinate} has a description matching a forbidden pattern."
        suggestion :forbidden_pattern, "Remove text that matches the forbidden pattern."
        on_elements

        def self.resolve_options(settings)
          options = super
          options.merge(forbidden_patterns: options[:forbidden_patterns].map { |pattern| Regexp.new(pattern, timeout: 1.0) })
        rescue RegexpError => error
          raise LintCore::InputError, "Invalid description-format.forbidden_patterns: #{error.message}"
        end

        private

        def check(member, event)
          return unless member.description && targets?(member, event)

          text = member.description.strip
          violation(member, :capitalized) if options[:capitalized] && /\A[a-z]/.match?(text)
          violation(member, :end_with_period) if options[:end_with_period] && !text.end_with?(".", "。")
          max = options[:max_length]
          violation(member, :max_length, max:) if max && text.length > max
          violation(member, :forbidden_pattern) if options[:forbidden_patterns].any? { |pattern| pattern.match?(text) }
        end
      end

      class NoHashtagDescription < BuiltinRule
        metadata "no-hashtag-description", :documentation, :warning, "Use a GraphQL description for API documentation."
        requires_source_text true
        message :violation, "%{coordinate} is preceded by a comment that will not appear in the schema."
        suggestion :violation, "Replace the comment with a GraphQL description."
        on_elements

        def setup(context)
          super
          @source_lines = @sources.to_h { |source| [source.path, source.lines] }
          @preceding_comments = @sources.to_h do |source|
            comments = source.comments.select do |comment|
              !comment.text.start_with?("graphql-lint-") &&
                source.lines.fetch(comment.line - 1)[0, comment.column - 1].strip.empty?
            end
            [source.path, comments.to_h { |comment| [comment.line + 1, comment] }]
          end
        end

        private

        def check(member, _event)
          return if member.description || !member.location
          path = member.location.path
          line = member.location.line
          return unless @preceding_comments.dig(path, line)

          prefix = @source_lines.fetch(path).fetch(line - 1)[0, member.location.column - 1]
          violation(member) if prefix.strip.empty?
        end
      end
    end
  end
end
