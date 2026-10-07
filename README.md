# Azure Cloud Engineering Portfolio

Hands-on Azure labs built around **Solstice Analytics**, a fictional B2B SaaS company that sells retail sales-analytics dashboards. Each lab solves a business problem the company would realistically face. I build it in the Azure Portal first to understand the service, rebuild it in **Terraform**, verify it, tear it down, and document the design decisions.

> Solstice Analytics is an invented scenario created for this portfolio. The Azure work is real and was built and tested in my own subscription.

## At a Glance

- **Who I am:** Microsoft Support Escalation Engineer (Microsoft Teams) moving into Azure cloud engineering.
- **What this repo shows:** how I design for least privilege, enforce governance with policy, codify infrastructure in Terraform, and document trade-offs and limitations honestly.
- **Status:** Labs 01 and 02 are complete. Labs 03–05 are in progress and will be added as each is finished.
- **Skills demonstrated so far:** Azure RBAC and custom roles · Microsoft Entra ID groups · Azure Policy (deny effect) · resource locks · Azure Storage (RA-GZRS, lifecycle management, SAS) · Private Link and private DNS · Terraform (`azurerm`, `azuread`) · governance design · technical documentation

## Featured: Lab 01 — Identities & Governance

[**Read the write-up →**](./Lab-01-Identity%20%26%20Governance/)

The scenario: a new Client Success team and two external contractors need access to a production subscription, with one rule from leadership: *nobody touches production by accident, nobody has more access than their job requires, and every resource is traceable to a cost center and an approved region.*

- Built a **custom least-privilege RBAC role** and assigned it to a group instead of individuals.
- Enforced **deny-effect Azure Policies** for a required `CostCenter` tag and approved regions only.
- Protected the core resource group with a **CanNotDelete lock**.
- Verified each guardrail by trying to break it, then **rebuilt everything in Terraform** (9 resources, clean apply and destroy).
- Documented a real constraint: PIM needs Entra ID P2, which the lab tenant doesn't have, so the write-up explains the production approach.

## Labs

| # | Lab | Focus | Status |
|---|-----|-------|--------|
| 01 | [Identities & Governance](./Lab-01-Identity%20%26%20Governance/) | RBAC, Entra ID groups, Azure Policy, resource locks | ✅ Complete |
| 02 | [Storage](./Lab-02-Storage/) | Secure storage, private endpoints and data ingestion | ✅ Complete |
| 03 | Compute | VM scale sets and container workloads | 🔜 Planned |
| 04 | Virtual Networking | Hub-and-spoke networking, isolation | 🔜 Planned |
| 05 | Monitor & Maintain | Monitoring, alerting, backup and recovery | 🔜 Planned |

The labs follow the five domains of the AZ-104 (Azure Administrator) exam, but each one is framed around a business problem rather than exam objectives.

### How the labs will connect

The series is designed to grow the way a real Azure environment does:

```
Lab 01 (Identities/Governance)
   └── RBAC and policy guardrails everything else deploys under

Lab 02 (Storage)              Lab 03 (Compute)
   └── ingestion pipeline        └── VMSS API + ACI batch processor
            \                    /
             \                  /
        Lab 04 (Virtual Networking)
           hub-spoke tying storage + compute together, isolating dev/prod
                        │
              Lab 05 (Monitor & Maintain)
           observes and backs up everything built in Labs 02–04
```

## How Each Lab Is Built

1. **Business problem:** a realistic requirement with a clear constraint.
2. **Portal build:** configured by hand first, with screenshots, to understand every setting.
3. **Terraform rebuild:** the same environment as code.
4. **Verification:** test that the guardrails actually work, not just that resources exist.
5. **Teardown:** destroy everything to keep costs near zero.
6. **Write-up:** architecture, design decisions, known limitations and future considerations.

Each lab folder contains a `README.md`, a `Terraform/` folder with the code, and a `Screenshots/` folder with the evidence.

## Tech Stack

- **IaC:** Terraform (`azurerm` + `azuread` providers)
- **Cloud:** Microsoft Azure (Pay-As-You-Go subscription, East US)
- **Tooling:** VS Code, PowerShell 7, Azure CLI
- **Version control:** Git / GitHub

## About Me

I work as a Microsoft Support Escalation Engineer, focused on complex Microsoft Teams issues. Many cases also call for adjacent troubleshooting across technologies like Entra ID, SharePoint and Exchange Online. I'm moving toward Azure cloud engineering and completing a B.S. in Cloud & Network Engineering at WGU. This repo is the hands-on side of that move: each lab is something I built and tested in a live subscription.

**Certifications:** AZ-900 · SC-900 · MS-900 · AI-900 · CompTIA Security+ · CompTIA A+

**Connect:** [LinkedIn — Romy Francis](https://www.linkedin.com/in/romy-francis)