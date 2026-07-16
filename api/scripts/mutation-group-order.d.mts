export interface ReplayEnvelope {
  event_sequence: number;
  mutation_group_id: string;
  group_ordinal: number;
  entity_type: string;
  entity_id: unknown;
  entity_revision: number;
  operation?: string;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
  [key: string]: unknown;
}

export interface ForeignKeyRelationship {
  child_table: string;
  child_columns: string[];
  parent_table: string;
  parent_columns: string[];
}

export function orderMutationGroups(
  envelopes: ReplayEnvelope[],
  canonicalJSONString?: (value: unknown) => string,
  foreignKeys?: ForeignKeyRelationship[],
): ReplayEnvelope[][];

export function foreignKeyRelationships(schemaContract: {
  constraints?: Array<{
    constraint_type: string;
    definition: string;
    table_name: string;
  }>;
}): ForeignKeyRelationship[];
