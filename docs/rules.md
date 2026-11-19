# Schema lint rules

Run `graphql-schema-lint rules` to see which presets enable each rule.

## `alphabetize`

Put schema definitions in a consistent order.

Default severity `warning`.

### Options

- `targets`. Type `string_list`. Default `["fields","input_fields","enum_values","arguments"]`. Values `fields`, `input_fields`, `enum_values`, `arguments`.
- `order`. Type `enum`. Default `"alphabetical"`. Values `alphabetical`, `lexicographical`.
- `groups`. Type `string_list`. Default `[]`.

### Invalid example

```graphql
type Query { zebra: Int aardvark: Int }
```

### Valid example

```graphql
type Query { aardvark: Int zebra: Int }
```

## `connection-type-structure`

Define connections with edges and page information.

Default severity `error`.

### Options

- `connection_pattern`. Type `string`. Default `"*Connection"`.
- `edges_field`. Type `string`. Default `"edges"`.
- `edge_pattern`. Type `string`. Default `"*Edge"`.
- `page_info_field`. Type `string`. Default `"pageInfo"`.
- `require_nodes_field`. Type `boolean`. Default `false`.
- `require_total_count`. Type `boolean`. Default `false`.

### Invalid example

```graphql
type Query { users: UserConnection } type UserConnection { edges: [UserEdge] pageInfo: PageInfo } type UserEdge { node: ID } type PageInfo { hasNextPage: Boolean! }
```

### Valid example

```graphql
type Query { users: UserConnection } type UserConnection { edges: [UserEdge] pageInfo: PageInfo! } type UserEdge { node: ID } type PageInfo { hasNextPage: Boolean! }
```

## `deprecation-reason-format`

Apply formatting and replacement-reference rules to deprecations.

Default severity `warning`.

### Options

- `pattern`. Type `regexp`. Default `null`.
- `min_length`. Type `integer`. Default `null`.
- `require_replacement_reference`. Type `boolean`. Default `false`.

### Invalid example

```graphql
type Query { old: ID @deprecated(reason: "Use `other`.") new: ID }
```

### Valid example

```graphql
type Query { old: ID @deprecated(reason: "Use `Query.new`.") new: ID }
```

## `description-format`

Apply formatting requirements to descriptions.

Default severity `warning`.

### Options

- `capitalized`. Type `boolean`. Default `true`.
- `end_with_period`. Type `boolean`. Default `false`.
- `max_length`. Type `integer`. Default `null`.
- `forbidden_patterns`. Type `string_list`. Default `[]`.
- `targets`. Type `string_list`. Default `["types","object_types","interface_types","union_types","enum_types","input_object_types","scalar_types","fields","root_fields","arguments","input_fields","enum_values","directives"]`. Values `types`, `object_types`, `interface_types`, `union_types`, `enum_types`, `input_object_types`, `scalar_types`, `fields`, `root_fields`, `arguments`, `input_fields`, `enum_values`, `directives`.

### Invalid example

```graphql
"queries" type Query { id: ID }
```

### Valid example

```graphql
"検索" type Query { id: ID }
```

## `description-style`

Use one string style for SDL descriptions.

Default severity `warning`.

### Options

- `style`. Type `enum`. Default `"block"`. Values `block`, `inline`.

### Invalid example

```graphql
"The query." type Query { id: ID }
```

### Valid example

```graphql
"""The query.""" type Query { id: ID }
```

## `directive-usage`

Apply project-specific schema directive requirements.

Default severity `error`.

### Options

- `requirements`. Type `array`. Default `[]`.

### Invalid example

```graphql
directive @auth(role: String) on FIELD_DEFINITION type Query { me: ID @auth(role: "member") }
```

### Valid example

```graphql
directive @auth(role: String) on FIELD_DEFINITION type Query { me: ID @auth(role: "admin") }
```

## `edge-type-structure`

Define edges with a cursor and a single node.

Default severity `error`.

### Options

- `edge_pattern`. Type `string`. Default `"*Edge"`.
- `cursor_types`. Type `string_list`. Default `["String!"]`.
- `node_kinds`. Type `string_list`. Default `["object","interface","union","enum","scalar"]`. Values `object`, `interface`, `union`, `enum`, `scalar`.
- `node_must_implement`. Type `string`. Default `null`.
- `match_node_name`. Type `boolean`. Default `false`.

### Invalid example

```graphql
type Query { user: UserEdge } type UserEdge { cursor: String! node: [ID] }
```

### Valid example

```graphql
type Query { user: UserEdge } type UserEdge { cursor: String! node: ID }
```

## `mutation-input-argument`

Group mutation arguments in a dedicated input object.

Default severity `error`.

### Options

- `argument_name`. Type `string`. Default `"input"`.
- `type_naming`. Type `string`. Default `"{FieldName}Input"`.
- `require_non_null`. Type `boolean`. Default `true`.
- `allow_no_arguments`. Type `boolean`. Default `true`.
- `additional_arguments`. Type `string_list`. Default `[]`.

### Invalid example

```graphql
type Query { id: ID } type Mutation { cancel(id: ID): Boolean }
```

### Valid example

```graphql
type Query { id: ID } type Mutation { cancel(input: CancelInput!): Boolean } input CancelInput { id: ID }
```

## `mutation-payload-fields`

Require or prohibit fields on mutation payloads.

Default severity `error`.

### Options

- `required_fields`. Type `array`. Default `[]`.
- `require_query_field`. Type `boolean`. Default `false`.
- `forbidden_fields`. Type `string_list`. Default `[]`.

### Invalid example

```graphql
type Query { id: ID } type Mutation { cancel: CancelPayload } type CancelPayload { ok: Boolean }
```

### Valid example

```graphql
type Query { id: ID } type Mutation { cancel: CancelPayload } type CancelPayload { message: String! }
```

## `mutation-payload-type`

Return a dedicated payload from each mutation.

Default severity `error`.

### Options

- `allowed_kinds`. Type `string_list`. Default `["object"]`. Values `object`, `interface`, `union`, `enum`, `scalar`.
- `allow_list`. Type `boolean`. Default `false`.
- `naming`. Type `string`. Default `"{FieldName}Payload"`.
- `unique`. Type `boolean`. Default `true`.
- `nullability`. Type `enum`. Default `"any"`. Values `any`, `nullable`, `non_null`.

### Invalid example

```graphql
type Query { id: ID } type Mutation { cancel: Boolean }
```

### Valid example

```graphql
type Query { id: ID } type Mutation { cancel: CancelPayload } type CancelPayload { ok: Boolean }
```

## `naming-convention`

Use consistent names for schema definitions.

Default severity `error`.

### Options

- `types`. Type `hash`. Default `{"style":"PascalCase"}`.
- `fields`. Type `hash`. Default `{"style":"camelCase"}`.
- `arguments`. Type `hash`. Default `{"style":"camelCase"}`.
- `input_fields`. Type `hash`. Default `{"style":"camelCase"}`.
- `enum_values`. Type `hash`. Default `{"style":"UPPER_CASE"}`.
- `directives`. Type `hash`. Default `{"style":"camelCase"}`.
- `object_types`. Type `hash`. Default `{}`.
- `interface_types`. Type `hash`. Default `{}`.
- `union_types`. Type `hash`. Default `{}`.
- `enum_types`. Type `hash`. Default `{}`.
- `input_object_types`. Type `hash`. Default `{}`.
- `scalar_types`. Type `hash`. Default `{}`.

### Invalid example

```graphql
type Query { user: legacy_user } type legacy_user { id: ID }
```

### Valid example

```graphql
type Query { user: HTTPRequest } type HTTPRequest { id: ID }
```

## `no-empty-description`

Reject empty schema descriptions.

Default severity `error`.

### Invalid example

```graphql
"　" type Query { id: ID }
```

### Valid example

```graphql
"The query." type Query { id: ID }
```

## `no-hashtag-description`

Use a GraphQL description for API documentation.

Default severity `warning`.

### Invalid example

```graphql
# Finds a user.
type Query { id: ID }
```

### Valid example

```graphql
# A comment.

type Query { id: ID }
```

## `no-typename-prefix`

Avoid repeating a type name at the start of its fields.

Default severity `warning`.

### Options

- `case_sensitive`. Type `boolean`. Default `false`.
- `include_input_objects`. Type `boolean`. Default `false`.
- `ignore`. Type `coordinate_patterns`. Default `[]`.

### Invalid example

```graphql
type Query { user: User } type User { userName: String }
```

### Valid example

```graphql
type Query { user: User } type User { name: String }
```

## `no-unpaginated-list`

Use pagination for lists of composite schema types.

Default severity `warning`.

### Options

- `element_kinds`. Type `string_list`. Default `["object","interface","union"]`. Values `object`, `interface`, `union`, `enum`, `scalar`.
- `connection_pattern`. Type `string`. Default `"*Connection"`.
- `allow`. Type `coordinate_patterns`. Default `[]`.

### Invalid example

```graphql
type Query { users: [User] } type User { id: ID }
```

### Valid example

```graphql
type Query { ids: [ID] }
```

## `no-unreachable-types`

Detect schema types that clients cannot reach.

Default severity `warning`.

### Options

- `ignore`. Type `coordinate_patterns`. Default `[]`.
- `check_directives`. Type `boolean`. Default `false`.

### Invalid example

```graphql
type Query { id: ID } type Orphan { id: ID }
```

### Valid example

```graphql
type Query { user: Person } interface Person { id: ID } type User implements Person { id: ID }
```

## `page-info-structure`

Define the page information required by connections.

Default severity `error`.

### Options

- `type_name`. Type `string`. Default `"PageInfo"`.
- `cursor_nullable`. Type `boolean`. Default `true`.

### Invalid example

```graphql
type Query { users: UserConnection } type UserConnection { count: Int }
```

### Valid example

```graphql
type Query { users: UserConnection } type UserConnection { pageInfo: PageInfo! } type PageInfo { hasNextPage: Boolean! hasPreviousPage: Boolean! startCursor: String endCursor: String }
```

## `pagination-arguments`

Declare count and cursor arguments on paginated fields.

Default severity `error`.

### Options

- `targets`. Type `hash`. Default `{"return_type_pattern":"*Connection","coordinates":[]}`.
- `direction`. Type `enum`. Default `"either"`. Values `forward`, `backward`, `both`, `either`.
- `count_type`. Type `string`. Default `"Int"`.
- `cursor_type`. Type `string`. Default `"String"`.
- `argument_names`. Type `hash`. Default `{"first":"first","after":"after","last":"last","before":"before"}`.

### Invalid example

```graphql
type Query { users(first: Int): UserConnection } type UserConnection { count: Int }
```

### Valid example

```graphql
type Query { users(last: Int!, before: String): UserConnection } type UserConnection { count: Int }
```

## `require-deprecation-date`

Set and enforce a removal date for deprecated elements.

Default severity `warning`.

### Options

- `source`. Type `enum`. Default `"reason"`. Values `reason`, `argument`.
- `pattern`. Type `regexp`. Default `"(\\d{4}-\\d{2}-\\d{2})"`.
- `argument`. Type `string`. Default `"deletionDate"`.
- `date_format`. Type `string`. Default `"%Y-%m-%d"`.
- `overdue`. Type `enum`. Default `"error"`. Values `off`, `info`, `warning`, `error`.

### Invalid example

```graphql
type Query { old: ID @deprecated(reason: "Remove on 2025-01-01") new: ID }
```

### Valid example

```graphql
type Query { old: ID @deprecated(reason: "Remove on 2030-01-01") new: ID }
```

## `require-deprecation-reason`

Explain why an API is deprecated.

Default severity `error`.

### Options

- `treat_default_reason_as_missing`. Type `boolean`. Default `true`.

### Invalid example

```graphql
type Query { old: ID @deprecated new: ID }
```

### Valid example

```graphql
type Query { old: ID @deprecated(reason: "Use `new`.") new: ID }
```

## `require-description`

Require descriptions for selected schema elements.

Default severity `warning`.

### Options

- `targets`. Type `string_list`. Default `["types"]`. Values `types`, `object_types`, `interface_types`, `union_types`, `enum_types`, `input_object_types`, `scalar_types`, `fields`, `root_fields`, `arguments`, `input_fields`, `enum_values`, `directives`.
- `ignore_relay_types`. Type `boolean`. Default `false`.
- `ignore`. Type `coordinate_patterns`. Default `[]`.

### Invalid example

```graphql
type Query { id: ID }
```

### Valid example

```graphql
"The query." type Query { id: ID }
```

## `root-field-nullability`

Use consistent outer nullability on root fields.

Default severity `warning`.

### Options

- `mode`. Type `enum`. Default `"nullable"`. Values `nullable`, `non_null`.
- `roots`. Type `string_list`. Default `["query","mutation"]`. Values `query`, `mutation`, `subscription`.

### Invalid example

```graphql
type Query { id: ID! }
```

### Valid example

```graphql
type Query { id: ID }
```

## `strict-id-in-types`

Require exactly one identifier on applicable object types.

Default severity `warning`.

### Options

- `accepted_names`. Type `string_list`. Default `["id"]`.
- `accepted_types`. Type `string_list`. Default `["ID!"]`.
- `exclude_suffixes`. Type `string_list`. Default `["Payload","Connection","Edge"]`.
- `exclude`. Type `coordinate_patterns`. Default `["PageInfo"]`.

### Invalid example

```graphql
type Query { user: User } type User { id: String! }
```

### Valid example

```graphql
type Query { user: User } type User { id: ID! }
```
