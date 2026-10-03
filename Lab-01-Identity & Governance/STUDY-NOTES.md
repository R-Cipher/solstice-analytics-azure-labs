# Lab 01 — AZ-104 Study Notes

Exam-prep notes for the identities and governance domain, kept separate from the lab write-up in [README.md](./README.md).

## What This Lab Covers

| Exam sub-skill | Where it shows up in this lab |
|---|---|
| Manage Entra ID users and groups | Creating `sg-client-success`, `sg-contractors-external`, adding members |
| Manage guest/external users | Inviting the two contractors as B2B guests |
| RBAC roles and scopes | Custom role definition + assignment at resource-group scope |
| Azure Policy | Tag enforcement + allowed-locations policy, both with `deny` effect |
| Resource locks | `CanNotDelete` lock and what it does/doesn't block (it doesn't block writes) |
| PIM | Eligible vs. active assignment, activation, justification, time-bound access (not implemented here; see README Known Limitations) |

## Key Concept

A resource lock set at a resource group is inherited by everything inside it, but a **more permissive** lock at a child resource can't override a **more restrictive** parent lock — the most restrictive lock in the chain always wins.

## Design Pattern Worth Knowing

Assigning roles to groups instead of individual users means onboarding and offboarding is a group-membership change rather than a role reassignment. This is the pattern the exam tests under managing groups.
