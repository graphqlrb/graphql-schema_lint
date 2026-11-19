# frozen_string_literal: true

module GraphQL
  module SchemaLint
    module Rules
      class RelayRule < BuiltinRule
        ARGUMENT_NAMES = %w[first after last before].to_h { |name| [name, name] }.freeze

        private

        def connection_targets(field, settings)
          pattern = value(settings, :return_type_pattern, "*Connection")
          collection_matches?([pattern].compact, field.type.named) ||
            collection_matches?(value(settings, :coordinates, []), field.coordinate)
        end

        def connection_types(pattern)
          pagination = @rule_options.dig("pagination-arguments", :targets) || {}
          explicit_types = @index.types.values.flat_map { |owner| owner.fields.values }
            .select { |field| connection_targets(field, pagination) }
            .map { |field| field.type.named }.to_set
          @index.types.values.select do |type|
            !type.builtin? && !type.prelude? &&
              (explicit_types.include?(type.name) || collection_matches?([pattern].compact, type.name))
          end.sort_by(&:name)
        end
      end

      class PaginationArguments < RelayRule
        metadata "pagination-arguments", :pagination, :error, "Declare count and cursor arguments on paginated fields."
        option :targets, type: :hash, default: {"return_type_pattern" => "*Connection", "coordinates" => []},
          schema: {return_type_pattern: :string, coordinates: :coordinate_patterns}
        option :direction, type: :enum, default: "either", values: %w[forward backward both either]
        option :count_type, type: :string, default: "Int"
        option :cursor_type, type: :string, default: "String"
        option :argument_names, type: :hash, default: ARGUMENT_NAMES,
          schema: ARGUMENT_NAMES.transform_values { :string }
        message :violation, "%{coordinate} does not declare the required pagination arguments."
        suggestion :violation, "Add or correct these arguments: %{arguments}."

        def on_field(field)
          return unless connection_targets(field, options[:targets])

          forward = invalid_arguments(field, %w[first after])
          backward = invalid_arguments(field, %w[last before])
          missing = case options[:direction]
          when "forward" then forward
          when "backward" then backward
          when "both" then forward + backward
          when "either" then [forward, backward].min_by(&:length)
          end
          violation(field, arguments: missing.join(", ")) unless missing.empty?
        end

        private

        def invalid_arguments(field, names)
          names.filter_map do |name|
            type = %w[first last].include?(name) ? options[:count_type] : options[:cursor_type]
            argument_name = value(options[:argument_names], name, name)
            argument = field.arguments[argument_name]
            "#{argument_name}: #{type}" unless argument && argument.type.named == type && !argument.type.list?
          end
        end
      end

      class NoUnpaginatedList < RelayRule
        metadata "no-unpaginated-list", :pagination, :warning, "Use pagination for lists of composite schema types."
        option :element_kinds, type: :string_list, default: %w[object interface union], values: OUTPUT_KINDS
        option :connection_pattern, type: :string, default: "*Connection"
        option :allow, type: :coordinate_patterns, default: []
        message :violation, "%{coordinate} returns an unpaginated list."
        suggestion :violation, "Return a connection such as `%{type}Connection` and add pagination arguments."

        def on_field(field)
          return unless field.type.list?
          return if collection_matches?([options[:connection_pattern], "*Edge"], field.owner.name)
          return if collection_matches?(options[:allow], field.coordinate)

          type = @index.types[field.type.named]
          violation(field, type: type.name) if type && options[:element_kinds].include?(type.kind.to_s)
        end
      end

      class ConnectionTypeStructure < RelayRule
        metadata "connection-type-structure", :relationships, :error, "Define connections with edges and page information."
        option :connection_pattern, type: :string, default: "*Connection"
        option :edges_field, type: :string, default: "edges"
        option :edge_pattern, type: :string, default: "*Edge"
        option :page_info_field, type: :string, default: "pageInfo"
        option :require_nodes_field, type: :boolean, default: false
        option :require_total_count, type: :boolean, default: false
        message :violation, "%{coordinate} has an invalid connection structure."
        suggestion :violation, "Define a connection object with these members: %{expected}."

        def on_schema(_index)
          connection_types(options[:connection_pattern]).each do |type|
            missing = missing_members(type)
            violation(type, expected: missing.join(", ")) unless missing.empty?
          end
        end

        private

        def missing_members(type)
          missing = []
          missing << "object type" unless type.kind == :object
          edges = type.fields[options[:edges_field]]
          edge = edges && @index.types[edges.type.named]
          unless edges && edges.type.wrappers.count(:list) == 1 &&
              edge&.kind == :object && collection_matches?([options[:edge_pattern]], edge.name)
            missing << "#{options[:edges_field]}: [Edge]"
          end
          page_info_name = @rule_options.dig("page-info-structure", :type_name) || "PageInfo"
          expected = "#{page_info_name}!"
          page_info = type.fields[options[:page_info_field]]
          missing << "#{options[:page_info_field]}: #{expected}" unless page_info&.type&.to_s == expected
          missing << "nodes" if options[:require_nodes_field] && !type.fields.key?("nodes")
          if options[:require_total_count] && type.fields["totalCount"]&.type&.to_s != "Int!"
            missing << "totalCount: Int!"
          end
          missing
        end
      end

      class EdgeTypeStructure < RelayRule
        metadata "edge-type-structure", :relationships, :error, "Define edges with a cursor and a single node."
        option :edge_pattern, type: :string, default: "*Edge"
        option :cursor_types, type: :string_list, default: ["String!"]
        option :node_kinds, type: :string_list, default: OUTPUT_KINDS, values: OUTPUT_KINDS
        option :node_must_implement, type: :string
        option :match_node_name, type: :boolean, default: false
        message :violation, "%{coordinate} has an invalid edge structure."
        suggestion :violation, "Define an edge object satisfying these requirements: %{expected}."

        def on_type(type)
          return unless collection_matches?([options[:edge_pattern]], type.name)

          missing = []
          missing << "object type" unless type.kind == :object
          cursor = type.fields["cursor"]
          missing << "cursor: #{options[:cursor_types].join(' or ')}" unless cursor && options[:cursor_types].include?(cursor.type.to_s)
          node = type.fields["node"]
          returned = node && @index.types[node.type.named]
          if node.nil? || node.type.list? || returned.nil? || !options[:node_kinds].include?(returned.kind.to_s)
            missing << "node: Node"
          else
            interface = options[:node_must_implement]
            missing << "node implements #{interface}" if interface && !implements?(returned, interface)
            name = "#{returned.name}Edge"
            missing << "edge name #{name}" if options[:match_node_name] && type.name != name
          end
          violation(type, expected: missing.join(", ")) unless missing.empty?
        end

        private

        def implements?(type, interface)
          seen = {}
          pending = type.interfaces.dup
          until pending.empty?
            name = pending.pop
            return true if name == interface
            next if seen[name]

            seen[name] = true
            pending.concat(@index.types[name].interfaces) if @index.types[name]
          end
          false
        end
      end

      class PageInfoStructure < RelayRule
        metadata "page-info-structure", :relationships, :error, "Define the page information required by connections."
        option :type_name, type: :string, default: "PageInfo"
        option :cursor_nullable, type: :boolean, default: true
        message :missing, "%{coordinate} is a connection, but the schema does not define `%{name}`."
        suggestion :missing, "Define the `%{name}` object with paging flags and cursor fields."
        message :violation, "%{coordinate} has an invalid page info structure."
        suggestion :violation, "Define a page info object with these members: %{expected}."

        def on_schema(index)
          pattern = @rule_options.dig("connection-type-structure", :connection_pattern) || "*Connection"
          connection = connection_types(pattern).first
          return unless connection

          name = options[:type_name]
          info = index.types[name]
          return violation(connection, :missing, name:) unless info
          return if info.prelude?

          cursor = options[:cursor_nullable] ? "String" : "String!"
          expected = {"hasNextPage" => "Boolean!", "hasPreviousPage" => "Boolean!", "startCursor" => cursor, "endCursor" => cursor}
          missing = expected.filter_map { |field, type| "#{field}: #{type}" unless info.fields[field]&.type&.to_s == type }
          missing.unshift("object type") unless info.kind == :object
          violation(info, expected: missing.join(", ")) unless missing.empty?
        end
      end
    end
  end
end
