-- Sanitized, read-only provider schema and migration-history contract.
-- The catalog fingerprints exclude volatile OIDs, owners, privileges, and rows.
with
table_rows as (
  select
    relation.relname as table_name,
    jsonb_build_object(
      'table_name', relation.relname,
      'relation_kind', relation.relkind,
      'persistence', relation.relpersistence,
      'row_security', relation.relrowsecurity,
      'force_row_security', relation.relforcerowsecurity,
      'replica_identity', relation.relreplident
    ) as contract_row
  from pg_class relation
  join pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public'
    and relation.relkind in ('r', 'p')
),
table_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(contract_row::text, E'\n' order by table_name),
        ''
      )
    ) as contract_md5
  from table_rows
),
column_rows as (
  select
    columns.table_name,
    columns.ordinal_position,
    jsonb_build_object(
      'table_name', columns.table_name,
      'column_name', columns.column_name,
      'ordinal_position', columns.ordinal_position,
      'data_type', columns.data_type,
      'udt_schema', columns.udt_schema,
      'udt_name', columns.udt_name,
      'character_maximum_length', columns.character_maximum_length,
      'numeric_precision', columns.numeric_precision,
      'numeric_scale', columns.numeric_scale,
      'datetime_precision', columns.datetime_precision,
      'is_nullable', columns.is_nullable,
      'column_default', columns.column_default,
      'is_identity', columns.is_identity,
      'identity_generation', columns.identity_generation
    ) as contract_row
  from information_schema.columns columns
  where columns.table_schema = 'public'
),
column_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(
          contract_row::text,
          E'\n'
          order by table_name, ordinal_position
        ),
        ''
      )
    ) as contract_md5
  from column_rows
),
constraint_rows as (
  select
    relation.relname as table_name,
    constraint_definition.conname as constraint_name,
    jsonb_build_object(
      'table_name', relation.relname,
      'constraint_name', constraint_definition.conname,
      'constraint_type', constraint_definition.contype,
      'definition', pg_get_constraintdef(constraint_definition.oid, true)
    ) as contract_row
  from pg_constraint constraint_definition
  join pg_class relation
    on relation.oid = constraint_definition.conrelid
  join pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public'
    and constraint_definition.contype <> 'n'
),
constraint_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(
          contract_row::text,
          E'\n'
          order by table_name, constraint_name
        ),
        ''
      )
    ) as contract_md5
  from constraint_rows
),
index_rows as (
  select
    table_definition.relname as table_name,
    index_definition.relname as index_name,
    jsonb_build_object(
      'table_name', table_definition.relname,
      'index_name', index_definition.relname,
      'definition', pg_get_indexdef(index_definition.oid),
      'is_unique', index_metadata.indisunique,
      'is_primary', index_metadata.indisprimary,
      'is_valid', index_metadata.indisvalid
    ) as contract_row
  from pg_index index_metadata
  join pg_class index_definition
    on index_definition.oid = index_metadata.indexrelid
  join pg_class table_definition
    on table_definition.oid = index_metadata.indrelid
  join pg_namespace namespace
    on namespace.oid = table_definition.relnamespace
  where namespace.nspname = 'public'
),
index_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(
          contract_row::text,
          E'\n'
          order by table_name, index_name
        ),
        ''
      )
    ) as contract_md5
  from index_rows
),
trigger_rows as (
  select
    relation.relname as table_name,
    trigger_definition.tgname as trigger_name,
    jsonb_build_object(
      'table_name', relation.relname,
      'trigger_name', trigger_definition.tgname,
      'definition', pg_get_triggerdef(trigger_definition.oid, true),
      'enabled_mode', trigger_definition.tgenabled
    ) as contract_row
  from pg_trigger trigger_definition
  join pg_class relation
    on relation.oid = trigger_definition.tgrelid
  join pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public'
    and not trigger_definition.tgisinternal
),
trigger_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(
          contract_row::text,
          E'\n'
          order by table_name, trigger_name
        ),
        ''
      )
    ) as contract_md5
  from trigger_rows
),
function_rows as (
  select
    procedure_definition.proname as function_name,
    pg_get_function_identity_arguments(procedure_definition.oid)
      as identity_arguments,
    jsonb_build_object(
      'function_name', procedure_definition.proname,
      'identity_arguments',
        pg_get_function_identity_arguments(procedure_definition.oid),
      'result', pg_get_function_result(procedure_definition.oid),
      'kind', procedure_definition.prokind,
      'definition', pg_get_functiondef(procedure_definition.oid),
      'security_definer', procedure_definition.prosecdef,
      'configuration',
        coalesce(to_jsonb(procedure_definition.proconfig), '[]'::jsonb)
    ) as contract_row
  from pg_proc procedure_definition
  join pg_namespace namespace
    on namespace.oid = procedure_definition.pronamespace
  where namespace.nspname = 'public'
    and procedure_definition.prokind in ('f', 'p')
),
function_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(
          contract_row::text,
          E'\n'
          order by function_name, identity_arguments
        ),
        ''
      )
    ) as contract_md5
  from function_rows
),
enum_rows as (
  select
    type_definition.typname as enum_name,
    enum_value.enumsortorder as sort_order,
    jsonb_build_object(
      'enum_name', type_definition.typname,
      'enum_label', enum_value.enumlabel,
      'sort_order', enum_value.enumsortorder::text
    ) as contract_row
  from pg_type type_definition
  join pg_namespace namespace
    on namespace.oid = type_definition.typnamespace
  join pg_enum enum_value
    on enum_value.enumtypid = type_definition.oid
  where namespace.nspname = 'public'
),
enum_contract as (
  select
    count(*) as row_count,
    md5(
      coalesce(
        string_agg(
          contract_row::text,
          E'\n'
          order by enum_name, sort_order
        ),
        ''
      )
    ) as contract_md5
  from enum_rows
),
catalog_contract as (
  select
    table_contract.row_count as table_properties_count,
    table_contract.contract_md5 as table_properties_md5,
    column_contract.row_count as column_count,
    column_contract.contract_md5 as columns_md5,
    constraint_contract.row_count as constraint_count,
    constraint_contract.contract_md5 as constraints_md5,
    index_contract.row_count as index_count,
    index_contract.contract_md5 as indexes_md5,
    trigger_contract.row_count as trigger_count,
    trigger_contract.contract_md5 as triggers_md5,
    function_contract.row_count as function_count,
    function_contract.contract_md5 as functions_md5,
    enum_contract.row_count as enum_label_count,
    enum_contract.contract_md5 as enum_labels_md5,
    md5(
      concat_ws(
        '|',
        table_contract.row_count::text,
        table_contract.contract_md5,
        column_contract.row_count::text,
        column_contract.contract_md5,
        constraint_contract.row_count::text,
        constraint_contract.contract_md5,
        index_contract.row_count::text,
        index_contract.contract_md5,
        trigger_contract.row_count::text,
        trigger_contract.contract_md5,
        function_contract.row_count::text,
        function_contract.contract_md5,
        enum_contract.row_count::text,
        enum_contract.contract_md5
      )
    ) as catalog_contract_md5
  from table_contract
  cross join column_contract
  cross join constraint_contract
  cross join index_contract
  cross join trigger_contract
  cross join function_contract
  cross join enum_contract
)
select jsonb_build_object(
  'observed_at_utc',
    to_char(
      statement_timestamp() at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    ),
  'database_name', current_database(),
  'runtime_marker', (
    select marker
    from runtime_database_markers
    where environment = 'production'
    order by marker
    limit 1
  ),
  'database_branch_id', (
    select branch_id
    from runtime_database_markers
    where environment = 'production'
    order by marker
    limit 1
  ),
  'migration_count', (
    select count(*) from drizzle.__drizzle_migrations
  ),
  'migration_head_id', (
    select id
    from drizzle.__drizzle_migrations
    order by id desc
    limit 1
  ),
  'migration_head_hash', (
    select hash
    from drizzle.__drizzle_migrations
    order by id desc
    limit 1
  ),
  'migration_history_md5', (
    select md5(string_agg(id::text || ':' || hash, ',' order by id))
    from drizzle.__drizzle_migrations
  ),
  'public_table_count', (
    select count(*)
    from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE'
  ),
  'public_table_names_md5', (
    select md5(
      string_agg(table_schema || '.' || table_name, ',' order by table_name)
    )
    from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE'
  ),
  'public_table_properties_count', catalog_contract.table_properties_count,
  'public_table_properties_md5', catalog_contract.table_properties_md5,
  'public_column_count', catalog_contract.column_count,
  'public_columns_md5', catalog_contract.columns_md5,
  'public_constraint_count', catalog_contract.constraint_count,
  'public_constraints_md5', catalog_contract.constraints_md5,
  'public_index_count', catalog_contract.index_count,
  'public_indexes_md5', catalog_contract.indexes_md5,
  'public_trigger_count', catalog_contract.trigger_count,
  'public_triggers_md5', catalog_contract.triggers_md5,
  'public_function_count', catalog_contract.function_count,
  'public_functions_md5', catalog_contract.functions_md5,
  'public_enum_label_count', catalog_contract.enum_label_count,
  'public_enum_labels_md5', catalog_contract.enum_labels_md5,
  'catalog_contract_md5', catalog_contract.catalog_contract_md5
) as greenfield_schema_readback
from catalog_contract;
