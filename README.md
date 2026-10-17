# Azure Cloud Engineering Portfolio

Hands-on Azure labs built around **Solstice Analytics**, a fictional B2B SaaS company that sells retail sales-analytics dashboards. Each lab solves a business problem the company would realistically face. I build it in the Azure Portal first to understand the service, rebuild it in **Terraform**, verify it, tear it down, and document the design decisions.

> Solstice Analytics is an invented scenario created for this portfolio. The Azure work is real and was built and tested in my own subscription.

## At a Glance

- **Who I am:** Microsoft Support Escalation Engineer (Microsoft Teams) moving into Azure cloud engineering.
- **What this repo shows:** how I design for least privilege, enforce governance with policy, codify infrastructure in Terraform, and document trade-offs and limitations honestly.
- **Status:** All five labs are complete.
- **Skills demonstrated so far:** Azure RBAC and custom roles · Microsoft Entra ID groups · Azure Policy (deny effect) · resource locks · Azure Storage (RA-GZRS, lifecycle management, SAS) · Private Link and private DNS · VM Scale Sets with autoscale · Azure Load Balancer · hub-and-spoke VNet peering · NSGs · NAT gateway · Azure Container Registry and Container Instances · managed identity · App Service · Log Analytics and KQL · metric and activity-log alerts with action groups · Azure Monitor Agent and data collection rules · Azure Backup (Recovery Services vault) · Terraform (`azurerm`, `azuread`) · governance design · technical documentation

## Featured: Lab 01 — Identities & Governance

[**Read the write-up →**](./Lab-01-Identity%20%26%20Governance/)

The scenario: a new Client Success team and two external contractors need access to a production subscription, with one rule from leadership: *nobody touches production by accident, nobody has more access than their job requires, and every resource is traceable to a cost center and an approved region.*

- I built a **custom least-privilege RBAC role** and assigned it to a group instead of individuals.
- I enforced **deny-effect Azure Policies** for a required `CostCenter` tag and approved regions only.
- I protected the core resource group with a **CanNotDelete lock**.
- I verified each guardrail by trying to break it, then **rebuilt everything in Terraform** (9 resources, clean apply and destroy).
- I documented a real constraint: PIM needs Entra ID P2, which my lab tenant doesn't have, so the write-up explains the production approach.

## Labs

| # | Lab | Focus | Status |
|---|-----|-------|--------|
| 01 | [Identities & Governance](./Lab-01-Identity%20%26%20Governance/) | RBAC, Entra ID groups, Azure Policy, resource locks | ✅ Complete |
| 02 | [Storage](./Lab-02-Storage/) | Secure storage, private endpoints and data ingestion | ✅ Complete |
| 03 | [Compute](./Lab-03-Compute/) | Zone-redundant VM scale set, container batch job, App Service | ✅ Complete |
| 04 | [Virtual Networking](./Lab-04-Virtual-Networking/) | Hub-and-spoke networking, NSG isolation, NAT gateway | ✅ Complete |
| 05 | [Monitor & Maintain](./Lab-05-Monitoring/) | Log Analytics, alerts, backup and recovery | ✅ Complete |

I followed the five domains of the AZ-104 (Azure Administrator) exam, but I framed each lab around a business problem rather than exam objectives.

### How the labs connect

I designed the series to grow the way a real Azure environment does:

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

![Labs 01 to 05 architecture](./Diagrams/solstice-platform-architecture.png)

## How I Build Each Lab

1. **Business problem:** I start with a realistic requirement and a clear constraint.
2. **Portal build:** I configure it by hand first to understand every setting.
3. **Terraform rebuild:** I recreate the same environment as code.
4. **Verification:** I test that the guardrails actually work, not just that resources exist.
5. **Teardown:** I destroy everything to keep costs near zero.
6. **Write-up:** I document the architecture, design decisions, known limitations and future considerations.

Each lab folder contains a `README.md`, a `Terraform/` folder with the code, and a `Diagrams/` and/or `Screenshots/` folder with the visuals.

## Tech Stack

- **IaC:** Terraform (`azurerm` + `azuread` providers)
- **Cloud:** Microsoft Azure (Pay-As-You-Go subscription, East US)
- **Tooling:** VS Code, PowerShell 7, Azure CLI
- **Version control:** Git / GitHub

## About Me

I work as a Microsoft Support Escalation Engineer, focused on complex Microsoft Teams issues. Many cases also call for adjacent troubleshooting across technologies like Entra ID, SharePoint and Exchange Online. I'm moving toward Azure cloud engineering and completing a B.S. in Cloud & Network Engineering at WGU. This repo is the hands-on side of that move: each lab is something I built and tested in a live subscription.

**Certifications:** Azure Administrator Associate · CompTIA Security+ · CompTIA A+

**Connect:** [LinkedIn — Romy Francis](https://www.linkedin.com/in/romy-francis)