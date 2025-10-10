# .agents Directory

This directory contains planning documents and task breakdowns for development work.

## Example Structure

```
.agents/
├── README.md           # This file
├── plans/             # High-level planning documents
│   └── PLAN_sidebar_refactor.md
├── tasks/             # Individual task breakdowns
│   ├── TASK_01_store_updates.md
│   ├── TASK_02_collapsible_mode_update.md
│   ├── TASK_03_create_toggle_component.md
│   ├── TASK_04_create_header_component.md
│   ├── TASK_05_integrate_header_component.md
│   ├── TASK_06_css_refinements.md
│   ├── TASK_07_accessibility_enhancements.md
│   ├── TASK_08_mobile_responsiveness.md
│   └── TASK_09_comprehensive_testing.md
└── prompts/           # Developer handoff prompts
    └── PROMPT_sidebar_refactor_handoff.md
```

## Metadata Format

### Plan Files

Each plan file includes YAML frontmatter with metadata:

```yaml
---
plan_id: sidebar_refactor
title: Sidebar Layout Refactor Plan
created: 2025-10-06
status: Planning Complete
total_tasks: 9
completed_tasks: 0
estimated_hours: 5-6
priority: High
tags: [ui, sidebar, refactor, accessibility]
---
```

### Task Files

Each task file includes YAML frontmatter linking it to its parent plan:

```yaml
---
task_id: 01
plan_id: sidebar_refactor
plan_file: ../plans/PLAN_sidebar_refactor.md
title: Store Updates (Optional Enhancement)
phase: Phase 1
created: 2025-10-06
status: Ready
priority: Low
estimated_minutes: 15
dependencies: []
tags: [zustand, state-management, optional]
---
```

## Metadata Fields

### Plan Metadata

- **plan_id**: Unique identifier for the plan (snake_case)
- **title**: Human-readable plan title
- **created**: Date created (YYYY-MM-DD)
- **status**: Current status (Planning Complete, In Progress, Completed, etc.)
- **total_tasks**: Total number of tasks in the plan
- **completed_tasks**: Number of completed tasks
- **estimated_hours**: Estimated time to complete all tasks
- **priority**: High, Medium, or Low
- **tags**: Array of relevant tags

### Task Metadata

- **task_id**: Sequential task number (01, 02, etc.)
- **plan_id**: ID of the parent plan
- **plan_file**: Relative path to parent plan file
- **title**: Human-readable task title
- **phase**: Which phase of the plan this task belongs to
- **created**: Date created (YYYY-MM-DD)
- **status**: Current status (Ready, In Progress, Completed, Blocked, etc.)
- **priority**: High, Medium, or Low
- **estimated_minutes**: Estimated time to complete
- **dependencies**: Array of task files this depends on
- **tags**: Array of relevant tags

## Usage

### Finding Tasks for a Plan

```bash
# List all tasks for sidebar_refactor plan
grep -l "plan_id: sidebar_refactor" .agents/tasks/*.md

# Get task status
grep -A 1 "task_id:" .agents/tasks/TASK_01_store_updates.md | grep "status:"
```
