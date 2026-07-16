import { createHash } from "node:crypto";

export async function liveSchemaContract(client) {
  const tables = await client.query(`
    select class.relname table_name, class.relkind
    from pg_class class
    join pg_namespace namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'public' and class.relkind in ('r', 'p')
    order by class.relname
  `);
  const columns = await client.query(`
    select table_name, column_name, ordinal_position, data_type, udt_name,
           is_nullable, column_default, is_identity, identity_generation
    from information_schema.columns
    where table_schema = 'public'
    order by table_name, ordinal_position
  `);
  const constraints = await client.query(`
    select relation.relname table_name, constraint_definition.conname constraint_name,
           constraint_definition.contype constraint_type,
           pg_get_constraintdef(constraint_definition.oid, true) definition
    from pg_constraint constraint_definition
    join pg_class relation on relation.oid = constraint_definition.conrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public' and constraint_definition.contype <> 'n'
    order by relation.relname, constraint_definition.conname
  `);
  const indexes = await client.query(`
    select tablename table_name, indexname index_name, indexdef definition
    from pg_indexes where schemaname = 'public'
    order by tablename, indexname
  `);
  const enums = await client.query(`
    select type_definition.typname enum_name, enum_value.enumlabel enum_value,
           enum_value.enumsortorder sort_order
    from pg_type type_definition
    join pg_namespace namespace on namespace.oid = type_definition.typnamespace
    join pg_enum enum_value on enum_value.enumtypid = type_definition.oid
    where namespace.nspname = 'public'
    order by type_definition.typname, enum_value.enumsortorder
  `);
  const functions = await client.query(`
    select procedure.proname function_name,
           pg_get_function_identity_arguments(procedure.oid) identity_arguments,
           pg_get_functiondef(procedure.oid) definition,
           procedure.prosecdef security_definer,
           procedure.proconfig configuration
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public' and procedure.proname like 'refwatch_%'
    order by procedure.proname, identity_arguments
  `);
  const triggers = await client.query(`
    select relation.relname table_name, trigger_definition.tgname trigger_name,
           pg_get_triggerdef(trigger_definition.oid, true) definition
    from pg_trigger trigger_definition
    join pg_class relation on relation.oid = trigger_definition.tgrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public' and not trigger_definition.tgisinternal
    order by relation.relname, trigger_definition.tgname
  `);
  const migrations = await client.query(`
    select id, hash from drizzle.__drizzle_migrations order by id
  `);
  return {
    tables: tables.rows,
    columns: columns.rows,
    constraints: constraints.rows,
    indexes: indexes.rows,
    enums: enums.rows,
    functions: functions.rows,
    triggers: triggers.rows,
    applied_migrations: migrations.rows,
  };
}

export async function livePrivilegeContract(client) {
  const tablePrivileges = await client.query(`
    select grantee, table_name, privilege_type, is_grantable
    from information_schema.role_table_grants
    where table_schema = 'public'
    order by grantee, table_name, privilege_type
  `);
  const functionPrivileges = await client.query(`
    select grantee, routine_name, privilege_type, is_grantable
    from information_schema.role_routine_grants
    where routine_schema = 'public' and routine_name like 'refwatch_%'
    order by grantee, routine_name, privilege_type
  `);
  return { table_privileges: tablePrivileges.rows, function_privileges: functionPrivileges.rows };
}

export function schemaContractDigest(contract) {
  return createHash("sha256").update(canonicalJSONString(contract)).digest("hex");
}

export function canonicalJSONString(value) {
  if (value === null || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "string") return JSON.stringify(normalizeTimestamp(value));
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Cannot hash non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJSONString).join(",")}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJSONString(value[key])}`).join(",")}}`;
}

function normalizeTimestamp(value) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return value;
  const timestamp = new Date(value);
  return Number.isNaN(timestamp.getTime()) ? value : timestamp.toISOString();
}
