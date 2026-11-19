# frozen_string_literal: true

module GraphQL
  module SchemaLint
    class Runner
      # @api public
      def run(config: nil, overrides: {})
        settings = LintCore::Config.load(config, defaults: DEFAULTS, presets: PRESETS, overrides:, filename: CONFIG_FILE)
        LintCore::Config.require_extensions(settings)
        active = active_rules(settings)
        loaded = load_schema(settings)
        return result(loaded.diagnostics, config: settings, sources: loaded.sources) if loaded.fatal?

        diagnostics = loaded.diagnostics.dup
        context = {
          index: loaded.index,
          sources: loaded.sources,
          config: settings,
          today: today(settings),
          rule_options: active.to_h { |klass, options, _| [klass.id, options] }
        }.freeze
        run_rules(active, settings, context, diagnostics)
        result(diagnostics, config: settings, sources: loaded.sources)
      rescue LintCore::InputError, LoadError, SyntaxError => error
        result([diagnostic("core/config-error", :error, error.message, fatal: true)], exit_status: 2)
      rescue StandardError => error
        warn(error.full_message) if (settings || overrides)["debug"]
        result([diagnostic("core/internal-error", :error, "Internal error: #{error.message}")], exit_status: 3)
      end

      private

      def active_rules(settings)
        registered = SchemaLint.rules
        only = Array(settings["only"])
        except = Array(settings["except"])
        entries = settings.fetch("rules", {})
        unless entries.is_a?(Hash)
          raise LintCore::InputError, "rules must be a mapping."
        end

        (entries.keys | only | except).each { |id| validate_rule!(id, registered) }

        entries.filter_map do |id, rule_settings|
          rule_settings = case rule_settings
          when true then {}
          when false then {"severity" => "off"}
          when Hash then rule_settings
          else {"severity" => rule_settings}
          end
          unknown = rule_settings.keys - %w[severity options exclude]
          unless unknown.empty?
            raise LintCore::InputError, "Unknown rule settings for #{id}: #{unknown.join(", ")}"
          end

          klass = registered.fetch(id)
          severity = rule_settings.fetch("severity", klass.default_severity).to_s
          unless %w[error warning info off].include?(severity)
            raise LintCore::InputError, "Invalid severity in rules.#{id}.severity: #{severity}"
          end
          exclusions = rule_settings.fetch("exclude", [])
          unless exclusions.is_a?(Array) && exclusions.all?(String)
            raise LintCore::InputError, "rules.#{id}.exclude must be a list of patterns."
          end
          options = klass.resolve_options(rule_settings.fetch("options", {}))
          next if severity == "off" || (!only.empty? && !only.include?(id)) || except.include?(id)

          [klass, options, severity.to_sym, exclusions]
        end
      end

      def validate_rule!(id, registered)
        return if registered.key?(id)

        alternatives = DidYouMean::SpellChecker.new(dictionary: registered.keys).correct(id.to_s)
        hint = " Did you mean #{alternatives.join(" or ")}?" unless alternatives.empty?
        raise LintCore::InputError, "Unknown schema rule #{id}.#{hint}"
      end

      def load_schema(settings)
        schema = settings["schema"]
        unless schema.is_a?(Hash) && (schema.keys - %w[sources prelude skip_checks]).empty?
          raise LintCore::InputError, "schema must contain sources, prelude, or skip_checks."
        end

        %w[prelude skip_checks].each { |key| LintCore::Config.check_strings(schema.fetch(key), "schema.#{key}") }
        LintCore::Config.optional_string(settings["emit_generated_sdl"], "emit_generated_sdl")
        LintCore::SchemaLoader.load(schema.fetch("sources"),
          prelude: schema.fetch("prelude", []),
          skip_checks: schema.fetch("skip_checks", []),
          emit_generated_sdl: settings["emit_generated_sdl"], repository: settings.dig("git", "repository"),
          locale: settings.fetch("locale", "en"))
      end

      def today(settings)
        value = settings["today"] || ENV["GRAPHQL_LINT_TODAY"]
        value ? Date.iso8601(value.to_s) : Date.today
      rescue Date::Error
        raise LintCore::InputError, "today must be a date in YYYY-MM-DD format."
      end

      def run_rules(active, settings, context, diagnostics)
        locale = settings.fetch("locale", "en")
        translations = Psych.safe_load_file(File.join(PACKAGE, "locales/#{locale}.yml")).fetch("rules")
        source_limited = context[:sources].any? { |source| %i[ruby introspection].include?(source.kind) }
        skipped = []
        walker = Walker.new(context[:index])

        active.each do |klass, options, severity, exclusions|
          if source_limited && klass.requires_source_text
            skipped << klass.id
            next
          end

          reports = []
          rule = klass.new(options:, severity:, locale:, diagnostics: reports, translations: translations.fetch(klass.id, {}))
          rule.setup(context)
          walker.each_event { |event, member| rule.public_send(event, member) }
          rule.finish
        rescue StandardError => error
          warn(error.full_message) if settings["debug"]
          diagnostics << diagnostic("core/rule-error", :error, "#{klass.id}: #{error.message}")
        ensure
          diagnostics.concat(reports.reject { |report| excluded?(report, exclusions) }) if reports
          reports = nil
        end

        unless skipped.empty?
          details = if locale == "ja"
            "この入力では実行できないルール: #{skipped.sort.join(", ")}"
          else
            "Rules requiring original SDL were skipped: #{skipped.sort.join(", ")}"
          end
          prior = diagnostics.select { |report| report.rule_id == "core/limited-input" }
          diagnostics.reject! { |report| report.rule_id == "core/limited-input" }
          message = (prior.map(&:message) << details).join(" ")
          diagnostics << diagnostic("core/limited-input", :info, message)
        end
      end

      def excluded?(report, patterns)
        patterns.any? do |pattern|
          coordinate = report.coordinate
          path = report.location&.path
          (coordinate && LintCore::CoordinatePattern.new(pattern).match?(coordinate)) ||
            (path && File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB))
        end
      end

      def diagnostic(id, severity, message, fatal: false)
        LintCore::Diagnostic.new(rule_id: id, severity:, message:, message_key: id.split("/").last, fatal:)
      end

      def result(diagnostics, **options)
        LintCore::Result.new(diagnostics:, tool: TOOL, version: VERSION, **options)
      end
    end
  end
end
