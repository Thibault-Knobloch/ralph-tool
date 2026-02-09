# Feature Spec: [Feature Name]

## Goal

**What user-visible change should exist when done?**

[1-2 lines describing the user-facing outcome]

**Success Criteria:**
- [How you'll know it worked - specific requirement that must be met]


## Non-goals

**Explicitly list what NOT to do (prevents scope creep):**
- [Out of scope item 1]
- [Out of scope item 2]

---

## Implementation Tasks

**Subtask 1: [Layer/Component Name]**
- **Requirements:**
  - [Specific requirement 1]
  - [Specific requirement 2]
- **Done when:** [Completion criteria]
- **Files:** [List of files to modify/create]

**Subtask 2: [Layer/Component Name]**
- **Requirements:**
  - [Specific requirement 1]
  - [Specific requirement 2]
- **Done when:** [Completion criteria]
- **Files:** [List of files to modify/create]

---

## Current State

**Where this lives:**
- Files/folders: `[path/to/relevant/files]`
- Related domains: `[domain1, domain2]`

**How it works today:**
- [Brief description of current behavior]

---

## Proposed Behavior

**Write as bullet rules, not prose:**

**Primary flow:**
- If [condition X], then [action Y]
- If [condition Z], then [action W]

**Edge cases:**
- When [edge case 1], [behavior]
- Error handling: [what happens on errors]

---

## UX / UI (if relevant)

**Screens/components affected:**
- `[component/path/file.tsx]` - [what changes]

**States to handle:**
- Empty state: [what shows when no data]
- Loading state: [what shows while loading]
- Error state: [what shows on error]
- Success state: [what shows on success]

---

## Data + APIs (if relevant)

**API endpoints:**
- `POST /api/[path]` - [description]
  - Request: `{ [field]: [type], ... }`
  - Response: `{ [field]: [type], ... }`

---

## Files to Touch

**Most likely files (Ralph should start here):**
- `path/to/file1.ts`
- `path/to/file2.tsx`

---

## Patterns and helpers

Reuse existing files where possible. Follow existing patterns in the project.

---

## Notes

**Additional context for Ralph:**
- [Any special considerations]
- [Dependencies on other features]
- [Known gotchas]

---

## How to Use This Template

1. Fill in all sections with specific requirements
2. Organize subtasks logically
3. Be specific in requirements and completion criteria
4. Omit sections that don't apply
5. Update prd.json with the task linking to this spec file
