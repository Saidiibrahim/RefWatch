import { describe, expect, it } from "vitest";
import {
  foreignKeyRelationships,
  orderMutationGroups,
  type ForeignKeyRelationship,
  type ReplayEnvelope,
} from "../scripts/mutation-group-order.mjs";

function event(overrides: Partial<ReplayEnvelope>): ReplayEnvelope {
  return {
    event_sequence: 1,
    mutation_group_id: "group-a",
    group_ordinal: 1,
    entity_type: "teams",
    entity_id: { id: "team-a" },
    entity_revision: 1,
    operation: "insert",
    before: null,
    after: { id: "team-a" },
    ...overrides,
  };
}

describe("mutation replay group ordering", () => {
  it("keeps an interleaved source transaction in one replay group", () => {
    const groups = orderMutationGroups([
      event({ event_sequence: 1, mutation_group_id: "group-a", group_ordinal: 1, entity_id: { id: "team-a" } }),
      event({ event_sequence: 2, mutation_group_id: "group-b", group_ordinal: 1, entity_id: { id: "team-b" } }),
      event({ event_sequence: 3, mutation_group_id: "group-a", group_ordinal: 2, entity_id: { id: "team-c" } }),
    ]);
    expect(groups.map((group) => group.map((item) => `${item.mutation_group_id}:${item.group_ordinal}`)))
      .toEqual([["group-a:1", "group-a:2"], ["group-b:1"]]);
  });

  it("orders groups by entity revision even when global sequence order disagrees", () => {
    const groups = orderMutationGroups([
      event({ event_sequence: 1, mutation_group_id: "group-b", entity_revision: 2 }),
      event({ event_sequence: 2, mutation_group_id: "group-a", entity_revision: 1 }),
    ]);
    expect(groups.map((group) => group[0]?.mutation_group_id)).toEqual(["group-a", "group-b"]);
  });

  it("rejects non-contiguous group ordinals", () => {
    expect(() => orderMutationGroups([
      event({ group_ordinal: 1 }),
      event({ event_sequence: 2, group_ordinal: 3, entity_id: { id: "team-b" } }),
    ])).toThrow(/Non-contiguous ordinals/);
  });

  it("orders a parent insert before a child insert when trigger sequence disagrees", () => {
    const foreignKeys: ForeignKeyRelationship[] = [{
      child_table: "team_members",
      child_columns: ["team_id"],
      parent_table: "teams",
      parent_columns: ["id"],
    }];
    const groups = orderMutationGroups([
      event({
        event_sequence: 1,
        mutation_group_id: "child",
        entity_type: "team_members",
        entity_id: { id: "member-a" },
        after: { id: "member-a", team_id: "team-a" },
      }),
      event({
        event_sequence: 2,
        mutation_group_id: "parent",
        entity_type: "teams",
        entity_id: { id: "team-a" },
        after: { id: "team-a" },
      }),
    ], JSON.stringify, foreignKeys);
    expect(groups.map((group) => group[0]?.mutation_group_id)).toEqual(["parent", "child"]);
  });

  it("orders child reassignment between creation of the new parent and deletion of the old parent", () => {
    const foreignKeys: ForeignKeyRelationship[] = [{
      child_table: "team_members",
      child_columns: ["team_id"],
      parent_table: "teams",
      parent_columns: ["id"],
    }];
    const groups = orderMutationGroups([
      event({
        event_sequence: 1,
        mutation_group_id: "delete-old",
        entity_type: "teams",
        entity_id: { id: "team-old" },
        operation: "delete",
        before: { id: "team-old" },
        after: null,
      }),
      event({
        event_sequence: 2,
        mutation_group_id: "reassign-child",
        entity_type: "team_members",
        entity_id: { id: "member-a" },
        operation: "update",
        before: { id: "member-a", team_id: "team-old" },
        after: { id: "member-a", team_id: "team-new" },
      }),
      event({
        event_sequence: 3,
        mutation_group_id: "create-new",
        entity_type: "teams",
        entity_id: { id: "team-new" },
        after: { id: "team-new" },
      }),
    ], JSON.stringify, foreignKeys);
    expect(groups.map((group) => group[0]?.mutation_group_id))
      .toEqual(["create-new", "reassign-child", "delete-old"]);
  });

  it("parses composite foreign keys from the bound schema contract", () => {
    expect(foreignKeyRelationships({ constraints: [{
      constraint_type: "f",
      table_name: "children",
      definition: "FOREIGN KEY (owner_id, season) REFERENCES parents(owner_id, season) ON DELETE CASCADE",
    }] })).toEqual([{
      child_table: "children",
      child_columns: ["owner_id", "season"],
      parent_table: "parents",
      parent_columns: ["owner_id", "season"],
    }]);
  });
});
