# Testing Harness Checks

## IMPORTANT: This file is meant to be run by a SUBAGENT

The orchestrator will delegate these checks to a SINGLE subagent that will handle all testing and provide feedback back to the orchestrator.

## Required Checks

### HARNESS 1: Build Check
**Location:** Project root (or adjust to your project structure)
**Command:** `npm run build` (or your build command)
**Success Criteria:**
- Build completes without errors
**Actions when failed:**
- Report errors back to orchestrator

### HARNESS 2: Type Check (if applicable)
**Location:** Project root
**Command:** `npm run typecheck` (or your type check command)
**Success Criteria:**
- No type errors
**Actions when failed:**
- Report type errors back to orchestrator

<!-- Add more harness checks as needed for your project -->

## Subagent Instructions

When you are invoked as the testing subagent:

1. **Run first check**
2. **If failures found:**
   - Return immediately to orchestrator with relevant context so orchestrator can fix it
3. **If passed, run next check**
4. **Continue until all checks pass or a failure is found**
5. **If all checks pass, SUCCESS! Return confirmation to the orchestrator**

## Important Notes

- Run checks AFTER all code changes are complete
- Don't run checks between individual file edits
- The orchestrator relies on you to handle the testing phase and return back any issues
