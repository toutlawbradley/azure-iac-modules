# Challenges & Decisions Log — Azure IaC Module Library

Real bugs, real decisions, real reasoning — logged as they happen, not reconstructed afterward.
Same discipline as GuardLine's log: if it took more than 10 minutes to figure out, or if there
was a real fork in the road, it goes here.

## How to use this file

For a **decision** (a fork where more than one reasonable option existed):
```
### [Phase] Decision: <short title>
**Date:** 
**Options considered:** 
**Chose:** 
**Why:** 
**What I'd reconsider if:** (what would change this call later)
```

For a **bug / debugging session** (something broke or didn't behave as expected):
```
### [Phase] Bug: <short title>
**Date:** 
**Symptom:** 
**Root cause:** 
**Fix:** 
**Lesson:** (what would make me catch this faster next time)
```

Log entries in the order they happen. Don't clean them up to look smarter in hindsight —
the wrong turns are the useful part.

---

## Phase 0 — Foundation

### [Phase 0] Decision: Terraform vs. Bicep

**Date:** 2026-08-03
**Options considered:** Terraform, Bicep
**Chose:** _(pending — working through this live)_
**Why:** _(pending)_
**What I'd reconsider if:** _(pending)_

---

<!-- New entries go below this line, in chronological order -->