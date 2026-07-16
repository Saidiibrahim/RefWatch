export function orderMutationGroups(envelopes, canonicalJSONString = JSON.stringify, foreignKeys = []) {
  const groups = new Map();
  for (const envelope of envelopes) {
    const values = groups.get(envelope.mutation_group_id) ?? [];
    values.push(envelope);
    groups.set(envelope.mutation_group_id, values);
  }
  for (const [groupId, values] of groups) {
    values.sort((left, right) => Number(left.group_ordinal) - Number(right.group_ordinal));
    values.forEach((value, index) => {
      if (Number(value.group_ordinal) !== index + 1) throw new Error(`Non-contiguous ordinals in group ${groupId}`);
    });
  }
  const edges = new Map([...groups.keys()].map((id) => [id, new Set()]));
  const indegree = new Map([...groups.keys()].map((id) => [id, 0]));
  const byEntity = new Map();
  for (const envelope of envelopes) {
    const key = `${envelope.entity_type}:${canonicalJSONString(envelope.entity_id)}`;
    const values = byEntity.get(key) ?? [];
    values.push(envelope);
    byEntity.set(key, values);
  }
  for (const [entity, values] of byEntity) {
    values.sort((left, right) => Number(left.entity_revision) - Number(right.entity_revision));
    for (let index = 1; index < values.length; index += 1) {
      const previous = values[index - 1];
      const current = values[index];
      if (Number(current.entity_revision) !== Number(previous.entity_revision) + 1) {
        throw new Error(`Non-contiguous revisions for ${entity}`);
      }
      addEdge(edges, indegree, previous.mutation_group_id, current.mutation_group_id);
    }
  }
  addForeignKeyEdges(envelopes, foreignKeys, edges, indegree, canonicalJSONString);
  const minimumSequence = (id) => Math.min(...groups.get(id).map((event) => Number(event.event_sequence)));
  const ready = [...groups.keys()].filter((id) => indegree.get(id) === 0).sort((a, b) => minimumSequence(a) - minimumSequence(b));
  const ordered = [];
  while (ready.length) {
    const id = ready.shift();
    ordered.push(groups.get(id));
    for (const next of edges.get(id)) {
      indegree.set(next, indegree.get(next) - 1);
      if (indegree.get(next) === 0) {
        ready.push(next);
        ready.sort((a, b) => minimumSequence(a) - minimumSequence(b));
      }
    }
  }
  if (ordered.length !== groups.size) throw new Error("Mutation-group dependency cycle detected");
  return ordered;
}

export function foreignKeyRelationships(schemaContract) {
  return (schemaContract?.constraints ?? [])
    .filter((constraint) => constraint.constraint_type === "f")
    .map((constraint) => {
      const match = /^FOREIGN KEY \(([^)]+)\) REFERENCES ([^ (]+)\(([^)]+)\)/.exec(constraint.definition);
      if (!match) throw new Error(`Unsupported foreign-key definition: ${constraint.definition}`);
      const childColumns = identifiers(match[1]);
      const parentColumns = identifiers(match[3]);
      if (childColumns.length !== parentColumns.length) throw new Error(`Foreign-key column mismatch: ${constraint.definition}`);
      return {
        child_table: constraint.table_name,
        child_columns: childColumns,
        parent_table: identifier(match[2]),
        parent_columns: parentColumns,
      };
    });
}

function addForeignKeyEdges(envelopes, foreignKeys, edges, indegree, canonicalJSONString) {
  for (const relationship of foreignKeys) {
    const parents = envelopes.filter((event) => event.entity_type === relationship.parent_table);
    const children = envelopes.filter((event) => event.entity_type === relationship.child_table);
    for (const child of children) {
      const beforeReference = referenceValues(child.before, relationship.child_columns);
      const afterReference = referenceValues(child.after, relationship.child_columns);
      for (const parent of parents) {
        const parentBefore = entityValues(parent, parent.before, relationship.parent_columns);
        const parentAfter = entityValues(parent, parent.after, relationship.parent_columns);
        const createsReferencedParent = afterReference && parentAfter && valuesEqual(afterReference, parentAfter, canonicalJSONString)
          && (!parentBefore || !valuesEqual(parentBefore, parentAfter, canonicalJSONString));
        if (createsReferencedParent) addEdge(edges, indegree, parent.mutation_group_id, child.mutation_group_id);

        const removesReferencedParent = beforeReference && parentBefore && valuesEqual(beforeReference, parentBefore, canonicalJSONString)
          && (!parentAfter || !valuesEqual(parentBefore, parentAfter, canonicalJSONString));
        if (removesReferencedParent) addEdge(edges, indegree, child.mutation_group_id, parent.mutation_group_id);
      }
    }
  }
}

function entityValues(event, snapshot, columns) {
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) return null;
  const entity = typeof event.entity_id === "string" ? parseEntityKey(event.entity_id) : event.entity_id;
  const fromEntity = referenceValues(entity, columns);
  return fromEntity ?? referenceValues(snapshot, columns);
}

function parseEntityKey(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function referenceValues(snapshot, columns) {
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) return null;
  const values = columns.map((column) => snapshot[column]);
  return values.some((value) => value === null || value === undefined) ? null : values;
}

function valuesEqual(left, right, canonicalJSONString) {
  return canonicalJSONString(left) === canonicalJSONString(right);
}

function addEdge(edges, indegree, from, to) {
  if (from === to || edges.get(from).has(to)) return;
  edges.get(from).add(to);
  indegree.set(to, indegree.get(to) + 1);
}

function identifiers(value) {
  return value.split(",").map((part) => identifier(part.trim()));
}

function identifier(value) {
  return value.replace(/^"|"$/g, "");
}
