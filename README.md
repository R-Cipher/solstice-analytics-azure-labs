# Solstice Analytics — Azure Administrator Portfolio

Hands-on Azure labs built around **Solstice Analytics**, a fictional B2B SaaS company that provides retail sales-analytics dashboards to mid-size retail chains. Each lab solves a real business problem the company would actually run into, mapped to one of the five current AZ-104: Microsoft Azure Administrator exam domains — built first in the Azure Portal to understand the service, then rebuilt in Terraform to codify it.

Built while studying for the AZ-104 retake as part of a transition from Microsoft Teams support escalation engineering into Azure cloud engineering.

## Labs

| # | Lab | AZ-104 Domain | Weight | Status |
|---|-----|----------------|--------|--------|
| 01 | [Identities & Governance](./lab-01-identities-governance/) | Manage Azure identities and governance | 20–25% | ✅ Complete |
| 02 | [Storage](./lab-02-storage/) | Implement and manage storage | 15–20% | ✅ Complete |
| 03 | [Compute](./lab-03-compute/) | Deploy and manage Azure compute resources | 20–25% | ✅ Complete |
| 04 | [Virtual Networking](./lab-04-virtual-networking/) | Implement and manage virtual networking | 15–20% | ✅ Complete |
| 05 | [Monitor & Maintain](./lab-05-monitoring/) | Monitor and maintain Azure resources | 10–15% | ✅ Complete |

Each lab folder contains:
- **README.md** — Business Problem, Architectural Design, Design Decisions, and Future Considerations, plus an AZ-104 theory-to-lab mapping table
- **terraform/** — the IaC rebuild of everything done manually in the portal
- **screenshots/** — portal walkthrough evidence, numbered to match the README's steps

## How the labs connect

The labs aren't five standalone exercises — they build on each other the way a real Azure environment grows:

```
Lab 01 (Identities/Governance)
   └── establishes the RBAC + policy guardrails everything else deploys under

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

## Tech stack

- **IaC:** Terraform (`azurerm` + `azuread` providers)
- **Cloud:** Microsoft Azure (Pay-As-You-Go subscription, East US)
- **Local tooling:** VS Code, PowerShell 7, Azure CLI
- **Version control:** Git / GitHub

## About this project

I'm a Microsoft Support Escalation Engineer moving toward Azure Cloud Engineering, currently studying for the AZ-104 (retake) and AZ-305 while completing a B.S. in Cloud & Network Engineering at WGU. This repo is the hands-on complement to that study — every lab is something I actually built and tore down in a live subscription, not just read about.

Connect: [GitHub — R-Cipher](https://github.com/R-Cipher)
