# Ralph Agent Knowledge Base

This file contains persistent learnings and patterns discovered across Ralph iterations.
Each iteration should update this file with new patterns, gotchas, and architectural insights
only if something new and relevant has been discovered.

**Progress Management:**
- Within feature: progress.txt accumulates task summaries
- Between features: progress.txt archives to `logs/progress/{feature-name}-progress-{timestamp}.txt`
- AGENT.md persists across all features (never cleared)
- NOTE: Do not create explainer documents or other documentation unless specifically asked to.

## CRITICAL: Code Reuse Philosophy

**NEVER ASSUME FUNCTIONALITY DOESN'T EXIST**
- Always search for existing implementations before creating new ones
- Check for utility functions that might already do what you need
- Look for similar patterns in other parts of the codebase
- Reuse existing services, stores, and API endpoints when possible

## Known Patterns

<!-- Add project-specific patterns here as you discover them -->

## Known Gotchas

<!-- Add project-specific gotchas here as you discover them -->
