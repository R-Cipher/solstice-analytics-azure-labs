# Lab 05 — Study Notes
**AZ-104 Domain:** Monitor and maintain Azure resources (10–15%)

These notes map Lab 05 to AZ-104 sub-skills. They are kept out of the lab README so the README stays focused on the project.

## What this lab exercises

| Exam sub-skill | Where it shows up in this lab |
|---|---|
| Log Analytics and diagnostic settings | Routing blob logs and metrics into one workspace; choosing the right resource and categories |
| KQL basics | Filtering, summarising by time bin, joining across two tables |
| Metric alerts and action groups | Threshold, aggregation, window and frequency; severity; notification channels |
| Activity log alerts | Alerting on administrative operations such as lock deletion |
| Azure Monitor Agent and data collection rules | Installing the agent, DCR, association, destination workspace |
| Azure Backup | Vault, policy, protected item, retention, recovery points, restore |

## Key concept to know cold

Azure Backup retention and Storage lifecycle management are **not the same tool for the same job**. Lifecycle policies move or expire blob data by age. Recovery Services backups create point-in-time recovery points you can restore *from*. The exam tests whether you pick the right one for a restore scenario.

## Related facts worth remembering

- **Platform metrics** (such as VM or scale-set CPU) need no agent. **Guest metrics and logs** (inside the OS) need the Azure Monitor Agent and a data collection rule.
- Blob logs come from the **blob service** diagnostic setting, not the storage account's.
- Azure Backup protects **individual VMs**; it is not a backup for uniform scale-set instances.
- A vault holding backup items can't be deleted until protection is stopped and the data deleted (and any soft-deleted data purged).
- Alert **frequency** is how often the rule is evaluated; **window** is the span of data it aggregates over.
- A metric alert's **window** only accepts fixed ISO 8601 values (PT1M, PT5M, PT15M, PT30M, PT1H, PT6H, PT12H, P1D). PT10M is rejected, which is why this lab's CPU alert uses a 15-minute window.
- Terraform's `recovery_service` provider feature controls what happens to backup data when a vault is destroyed. When the block is set, the `vm_backup_*` flag has to be declared too.
- In the azurerm 5.x `azurerm_recovery_services_vault` resource, soft delete can't be set directly. Deletion behaviour comes from the provider's purge setting.
- Action groups are reusable: one group can serve many alert rules.
