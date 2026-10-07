# Lab 02 — Storage
**Solstice Analytics — Azure Cloud Engineering Portfolio**
**AZ-104 Domain:** Implement and manage storage (15–20%)

> **Note:** Solstice Analytics is a fictional company created for a personal portfolio lab series. The scenario is invented; the Azure work is real and was built and tested in my own subscription.

## Summary

- **Built** an RA-GZRS storage account with two containers, a lifecycle policy that tiers raw exports from Hot to Cool to Cold and deletes them after a year, and a private endpoint with private DNS so the account is not reachable from the internet.
- **Extended Lab 01** by assigning the same `Require CostCenter Tag` and `Allowed Locations` policies to the new resource groups (looked up from Lab 01's policy definition) and giving the `sg-client-success` group read-only access to processed output.
- **Started the network** that Labs 03 and 04 grow: the prod VNet (`vnet-solstice-prod`) and its `subnet-data`, which hosts the private endpoint.
- **Verified** that test manifests upload with a SAS token, then that the same upload is refused (`403 AuthorizationFailure`) once public access is turned off.
- **Rebuilt as Infrastructure as Code:** portal first, then Terraform (16 resources, applied cleanly).

**Jump to:** [Business Problem](#business-problem) · [Architectural Design](#architectural-design) · [Design Decisions](#design-decisions) · [Future Considerations](#future-considerations)

**Tools:** Microsoft Azure · Azure Storage · Private Link · Azure DNS · Azure RBAC · Terraform · AzCopy · Azure CLI

---

## Builds On Lab 01

| From Lab 01 | How this lab uses it |
|---|---|
| Custom policy `require-costcenter-tag` | Assigned to `rg-solstice-data` and `rg-solstice-network`; every resource below carries `CostCenter = SOL-001` |
| Built-in `Allowed locations` policy | Assigned to both new resource groups (East US / East US 2) |
| Entra group `sg-client-success` | Receives `Storage Blob Data Reader` on the `processed` container |

**Before you start:** Lab 01 must be applied. If you destroyed it after finishing, run `terraform apply` in the Lab 01 `Terraform` folder first. Group membership was added by hand in the portal, so re-add members if you want to test the Client Success read access.

## Business Problem

Every night, Solstice's retail clients push POS export files (CSV manifests of daily sales) into Azure so the analytics pipeline can process them by morning. Two requirements came out of a recent client security review:

> "The storage account can't be reachable from the open internet, and old raw exports need to age out of expensive storage automatically instead of someone remembering to clean them up."

Today the storage account has a public endpoint and no lifecycle policy, so every file, no matter how old, sits in Hot tier forever.

## Architectural Design

Clients and pipeline workloads reach the storage account through a **private endpoint** in `subnet-data`. A **private DNS zone**, linked to the VNet, makes the storage name resolve to the endpoint's private IP (`10.1.2.4`). With public network access turned off, anything outside the VNet is refused.

![Private endpoint architecture: client inside the VNet reaches the storage account through the private endpoint and Private Link; the public internet path is blocked](./Diagrams/private-endpoint-architecture.svg)

**Why the lockdown works.** The same storage name resolves differently depending on where the request starts. Inside the VNet the linked private zone answers with the private IP; outside it, DNS returns the public address and the storage firewall refuses the request.

![Name resolution: inside the VNet resolves to 10.1.2.4 and is allowed; from the internet there is no linked zone and the request is refused with a 403](./Diagrams/private-dns-resolution.svg)

| Layer | Resources (16 in Terraform) | Purpose |
|---|---|---|
| Governance | 2 resource groups, 4 policy assignments (`require-costcenter` and `allowed-locations` on each group) | Extends Lab 01's tag and location controls to everything built here |
| Network | `vnet-solstice-prod` (10.1.0.0/16), `subnet-data` (10.1.2.0/24) | Final-form prod network; later labs add subnets, not replacements |
| Storage | RA-GZRS account, `raw-manifests` and `processed` containers, lifecycle policy | Resilient storage with automatic tiering and expiry of raw exports |
| Private access | Private endpoint, `privatelink.blob.core.windows.net` zone, VNet link | Removes the public path and resolves the storage name privately |
| Access control | `Storage Blob Data Reader` for `sg-client-success` on `processed` | Group-based, read-only access, no keys |

Resource layout:

```
Lab 01 (already exists)
├── rg-solstice-core  — groups, custom role, policies, lock
└── Subscription-level custom policy: require-costcenter-tag

Lab 02 adds
├── rg-solstice-data
│   ├── Storage account: stsolsticedata<suffix>  (RA-GZRS)
│   │     ├── Container: raw-manifests   (Hot → Cool at 30d → Cold at 90d → delete at 365d)
│   │     └── Container: processed       (Hot, no automatic tiering)
│   ├── Private DNS zone: privatelink.blob.core.windows.net
│   │     └── VNet link → vnet-solstice-prod
│   ├── Private endpoint: pe-stsolsticedata-blob  (in subnet-data)
│   └── RBAC: sg-client-success → Storage Blob Data Reader on "processed"
│
└── rg-solstice-network   (shared by Labs 02–04)
    └── vnet-solstice-prod (10.1.0.0/16)
          └── subnet-data (10.1.2.0/24)   ← private endpoint lives here
```

The prod VNet is created here, in its final form, rather than as a throwaway stub. Lab 03 adds compute subnets to it and Lab 04 peers it to the hub, so nothing built in this lab has to be replaced later.

## Design Decisions

- **RA-GZRS over LRS.** Retail clients' sales data feeds board-level reporting, and Solstice can't afford a single-region outage taking down ingestion. RA-GZRS gives zone redundancy in the primary region plus geo-replication, and read access to the secondary copy if the primary region is unavailable, so dashboards can keep reading during an outage.
- **Private endpoint instead of storage firewall IP rules.** IP allowlisting breaks the moment a client's network changes. A private endpoint takes the account off the public internet and routes traffic over the Microsoft backbone.
- **Lifecycle policy on `raw-manifests` only.** Raw exports are disposable once processed, so they move to cheaper tiers and are eventually deleted. `processed` feeds the dashboards, so it stays in Hot with no automatic rule.
- **Cool, then Cold, then delete, instead of Archive.** The original plan tiered to Archive at 90 days, but the portal didn't offer it. Archive isn't supported on ZRS, GZRS or RA-GZRS accounts, and this account is RA-GZRS. Solstice's ingestion has to survive a zone or regional outage, and that outweighs the extra savings of Archive, so the account keeps RA-GZRS and the policy uses Cold, which supports every redundancy option. A business whose goal was long-term retention would reasonably choose differently: GRS or RA-GRS with Archive, accepting the loss of zone redundancy in the primary region.
- **Delete after 365 days.** The requirement was that old exports shouldn't sit in expensive storage "instead of someone remembering to clean them up." Tiering lowers the cost, and the delete rule means the files don't accumulate forever. Raw exports are reproducible from the clients' own systems and the useful output lives in `processed`, so a year is a reasonable starting point, flagged as a business decision to revisit with the retention requirements of each client.
- **SAS tokens for client uploads, not account keys.** A short-lived, container-scoped SAS limits a leaked credential to one container for a limited time.
- **Group-based, read-only data access.** Client Success reads processed output through an RBAC role on the container, not through keys, following Lab 01's "groups, not individuals" pattern.
- **Reusing Lab 01's governance.** The tag and location policies are assigned to every new resource group, so the controls from Lab 01 apply to everything built afterwards.

## Known Limitations

- **A SAS token does not bypass the network path.** Once public access is disabled, a valid SAS is still refused from the internet. Uploads then have to come from inside the VNet (the Lab 04 ops VM, or the Lab 03 batch job using managed identity). Clients outside the network would need their own private connectivity or a different ingestion design.
- **Terraform runs from a laptop, outside the VNet.** After lock-down, only management-plane resources can be managed from there. That is why the containers use `storage_account_id` and the lifecycle policy is a management-plane resource. Anything that needs blob data-plane access from Terraform would fail.
- **The portal can't tag private DNS virtual network links.** With a deny tag policy in place, the link had to be created with the Azure CLI (see Findings).
- **Archive tier isn't available on this account.** RA-GZRS doesn't support it (see Design Decisions), so raw exports stop at Cold. Using Archive would mean switching to GRS or RA-GRS and giving up zone redundancy in the primary region.
- **Lifecycle rules take effect over days.** The 30-, 90- and 365-day actions can't be demonstrated live. The lab shows the rule exists and is scoped correctly; it doesn't prove a blob moved tier or was deleted. Rules also run on a daily schedule rather than instantly.
- **Deletion is permanent.** Once the delete rule runs, the raw file is gone unless blob soft delete or versioning is enabled, which this lab doesn't configure.
- **Account keys are still enabled** because the SAS demo needs them. Production would use a user-delegation SAS (Entra-backed) and disable shared key access.

## Future Considerations

- Add an Event Grid trigger on `raw-manifests` blob-created events so processing starts automatically (Lab 03's batch job is started by hand).
- Replace the deny tag policy's gaps with a `Modify` policy that inherits `CostCenter` from the resource group, so resources the portal can't tag are tagged automatically instead of blocked.
- Enable blob soft delete so a mistaken delete (or the lifecycle delete rule) is recoverable for a window.
- Consider Data Lake Storage Gen2 (hierarchical namespace) if the pipeline needs directory-level ACLs.
- Move to user-delegation SAS and `shared_access_key_enabled = false`.

*Exam-prep notes mapping this lab to AZ-104 sub-skills are kept separately in [STUDY-NOTES.md](./STUDY-NOTES.md).*

---

## Step 1 — Build It in the Portal

1. **Create the resource groups.** `rg-solstice-data` and `rg-solstice-network`, both East US, both tagged `CostCenter = SOL-001`.

2. **Assign the Lab 01 policies.** On each new resource group: Policy → Assignments → assign `Require CostCenter Tag` (custom) and the built-in `Allowed locations` (East US, East US 2).

3. **Create the prod VNet.** `vnet-solstice-prod`, 10.1.0.0/16, in `rg-solstice-network`, with one subnet `subnet-data` (10.1.2.0/24). In the subnet's settings, set **Private endpoint network policy** to *Network security groups* so Lab 04's NSG can apply to the endpoint.

4. **Create the storage account** `stsolsticedata001`: Standard performance, RA-GZRS, tagged. Public access stays enabled for now, for the upload test.

   ![Storage account with RA-GZRS replication and CostCenter tag](./Screenshots/GZRS%20Storage%20Account.png)

5. **Create the containers** `raw-manifests` and `processed`. (`$logs` is created by Azure.)

   ![Storage containers](./Screenshots/Storage%20Containers.png)

6. **Set the lifecycle policy.** Storage account → Data management → Lifecycle management → Add rule, scoped to the `raw-manifests/` prefix: Cool after 30 days since modification, Cold after 90, delete after 365. Archive is not offered on an RA-GZRS account (see Findings).

   ![Lifecycle rule enabled](./Screenshots/Lifecycle%20Management%20Rule.png)
   ![Lifecycle actions: Cool at 30 days, Cold at 90, delete at 365](./Screenshots/Lifecycle%20Management%20Rule%20Definitions.png)
   ![Lifecycle rule scoped to the raw-manifests/ prefix](./Screenshots/Lifecycle%20Management%20Scope.png)

7. **Grant read access.** On the `processed` container → Access control (IAM) → add `Storage Blob Data Reader` for `sg-client-success`.

   ![sg-client-success with Storage Blob Data Reader on the processed container](./Screenshots/Client%20Success%20IAM.png)

8. **Test a SAS upload (public access still on).** The first SAS was generated with Read and Add permissions only, and AzCopy was refused with `AuthorizationPermissionMismatch`. Regenerating it with Create and Write fixed the upload.

   ![AzCopy refused: SAS missing the Create/Write permissions](./Screenshots/AzCopy%20SAS%20permission%20error.png)
   ![Test manifests uploaded to raw-manifests](./Screenshots/Sample%20Manifests.png)

   *In the portal build the manifests were uploaded as one zip. The Terraform build uploads the three CSVs individually, because Lab 03's batch job reads `.csv` files.*

9. **Create the private DNS zone and link it to the VNet, with tags.** The private endpoint wizard tries to create the zone's virtual network link for you, but it gives no way to tag that link, so the Lab 01 `Require CostCenter Tag` policy denies the deployment. The Activity log confirms the denied resource was the `virtualNetworkLinks` resource (see Findings).

   ![Private endpoint deployment denied by the CostCenter tag policy](./Screenshots/Tagging%20Policy%20Denial.png)
   ![Activity log: deny on the privateDnsZones/virtualNetworkLinks resource](./Screenshots/Tagging%20Policy%20Denial%202.png)

   The fix was to create the zone (tagged) in `rg-solstice-data` in the portal, then create the link with the Azure CLI, which accepts tags:

   ```powershell
   $vnetId = az network vnet show -g rg-solstice-network -n vnet-solstice-prod --query id -o tsv
   az network private-dns link vnet create -g rg-solstice-data -z privatelink.blob.core.windows.net `
     -n link-vnet-solstice-prod -v $vnetId -e false --tags CostCenter=SOL-001
   ```

   ![Virtual network link created with the Azure CLI, CostCenter tag applied](./Screenshots/Private%20DNS%20Link%20AzCLI.png)
   ![Virtual network link to vnet-solstice-prod, status Completed](./Screenshots/Private%20DNS%20Zone%20VNET%20Link.png)

10. **Create the private endpoint.** Storage account → Networking → Private endpoints → Create: sub-resource `blob`, VNet `vnet-solstice-prod`, subnet `subnet-data`, and integrate with the existing `privatelink.blob.core.windows.net` zone. With the link already in place, the deployment succeeds.

    ![Private endpoint connection Approved](./Screenshots/Private%20Endpoint%20Connection%20Approved.png)
    ![Private endpoint DNS configuration: storage FQDN mapped to 10.1.2.4](./Screenshots/Private%20Endpoint%20DNS.png)
    ![Private DNS zone A record for stsolsticedata001 pointing to 10.1.2.4](./Screenshots/Private%20DNS%20Zone%20A%20Record.png)

11. **Disable public network access** on the storage account.

    ![Public network access disabled](./Screenshots/Storage%20Public%20Access%20Off.png)

12. **Verify the lockdown.** The same AzCopy upload with a valid SAS now fails with `AuthorizationFailure`. The SAS is fine; the network path is closed. Browsing the container in the portal from outside the VNet is refused the same way. Account settings, networking and deletion still work, because those go through Azure Resource Manager rather than the blob endpoint.

    ![AzCopy refused after lockdown: AuthorizationFailure](./Screenshots/AzCopy%20SAS%20public%20network%20access%20blocked%20error.png)
    ![Portal blob view refused from outside the network](./Screenshots/403%20Portal%20Access%20Error.png)

### Findings From the Portal Build

1. **Two different 403s, two different causes.** `AuthorizationPermissionMismatch` meant the SAS token was valid but lacked the right permissions: *Add* only appends to append blobs, while uploading a new block blob needs *Create* or *Write*. `AuthorizationFailure` after lockdown meant the network path was closed, regardless of the token. Reading the error code, not just the status code, told the two apart.
2. **The portal can't tag a private DNS virtual network link, so a deny tag policy blocks it.** The private endpoint wizard creates the link with a generated name and no tags, and the Lab 01 policy correctly denied it. Rather than weakening the policy to `audit`, the link was created with the Azure CLI, which supports tags. In production the cleaner fix is a policy with the `Modify` effect (for example, inherit `CostCenter` from the resource group), which adds the tag instead of rejecting the resource. Terraform avoids the problem because the link is its own resource with `tags`.
3. **Archive isn't available on RA-GZRS.** Microsoft documents that Archive only supports LRS, GRS and RA-GRS. The lifecycle policy uses Cold instead (see Design Decisions).

## Step 2 — Rebuild It in Terraform

The portal build is repeated as code. Remove the portal-built resources first so Terraform can create everything from scratch.

```
Terraform/
├── providers.tf
├── variables.tf
├── data.tf
├── main.tf
├── outputs.tf
└── .terraform.lock.hcl
```

The `subscription_id` and `name_suffix` go in a local `terraform.tfvars` that stays out of version control:

```hcl
subscription_id = "00000000-0000-0000-0000-000000000000"
name_suffix     = "rf01"   # lowercase letters/digits; keeps global names unique
```

### Implementation Notes

- **`data.tf` is the link to Lab 01.** Terraform doesn't share state between folders, so this lab *looks up* Lab 01's group and policy definitions by name instead of redefining them. If Lab 01 isn't applied, `plan` fails here, which is the correct behaviour.
- **Policy assignments use `for_each`** over both new resource groups, so one block covers both.
- **`lock_down_public_access` makes the lockdown a deliberate second apply.** Apply with the default (`false`), upload the test files, then apply again with `-var="lock_down_public_access=true"`.
- **Containers use `storage_account_id`**, which talks to the management plane. A container created through the storage endpoint would fail once public access is off.
- **`private_endpoint_network_policies = "Enabled"`** on `subnet-data` is what lets the Lab 04 NSG filter traffic to the endpoint. Without it NSG rules are silently ignored for private endpoints.
- **The DNS zone link** is what makes the storage name resolve to the private IP from inside the VNet.
- **The RBAC scope is the container**, using `resource_manager_id`, so Client Success can read `processed` but not `raw-manifests`.

### Terraform Code

<details>
<summary><code>providers.tf</code></summary>

```hcl
# Azure Provider source and versions
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}
```

</details>

<details>
<summary><code>variables.tf</code></summary>

```hcl
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "name_suffix" {
  type        = string
  description = "Short lowercase suffix that makes globally unique names unique (for example your initials plus two digits)"
}

variable "lock_down_public_access" {
  type        = bool
  description = "false = storage account reachable from the internet (used to upload test files). true = public access disabled."
  default     = false
}
```

</details>

<details>
<summary><code>data.tf</code></summary>

```hcl
# Lab 01 outputs, looked up by name. Lab 01 must be applied first.
data "azuread_group" "client_success" {
  display_name     = "sg-client-success"
  security_enabled = true
}

data "azurerm_policy_definition" "require_costcenter" {
  name = "require-costcenter-tag"
}

data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
}
```

</details>

<details>
<summary><code>main.tf</code></summary>

```hcl
locals {
  location = "eastus"
  tags = {
    CostCenter = "SOL-001"
  }
}

# ---------- Resource groups ----------
resource "azurerm_resource_group" "data" {
  name     = "rg-solstice-data"
  location = local.location
  tags     = local.tags
}

# Shared by Labs 02-04. Lab 02 creates it because the private endpoint needs a subnet.
resource "azurerm_resource_group" "network" {
  name     = "rg-solstice-network"
  location = local.location
  tags     = local.tags
}

# ---------- Lab 01 governance, extended to the new resource groups ----------
locals {
  governed_rgs = {
    data    = azurerm_resource_group.data.id
    network = azurerm_resource_group.network.id
  }
}

resource "azurerm_resource_group_policy_assignment" "require_costcenter" {
  for_each             = local.governed_rgs
  name                 = "require-costcenter"
  display_name         = "Require CostCenter Tag"
  resource_group_id    = each.value
  policy_definition_id = data.azurerm_policy_definition.require_costcenter.id
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  for_each             = local.governed_rgs
  name                 = "allowed-locations"
  display_name         = "Allowed Locations: East US, East US 2"
  resource_group_id    = each.value
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  parameters = jsonencode({
    "listOfAllowedLocations" = {
      "value" = ["eastus", "eastus2"]
    }
  })
}

# ---------- Network foundation (prod spoke, grown in Labs 03 and 04) ----------
resource "azurerm_virtual_network" "prod" {
  name                = "vnet-solstice-prod"
  resource_group_name = azurerm_resource_group.network.name
  location            = local.location
  address_space       = ["10.1.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "data" {
  name                 = "subnet-data"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.prod.name
  address_prefixes     = ["10.1.2.0/24"]

  # Lets NSGs (added in Lab 04) apply to the private endpoint
  private_endpoint_network_policies = "Enabled"
}

# ---------- Storage ----------
resource "azurerm_storage_account" "solstice" {
  name                     = "stsolsticedata${var.name_suffix}"
  resource_group_name      = azurerm_resource_group.data.name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "RAGZRS"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false
  public_network_access_enabled   = !var.lock_down_public_access

  tags = local.tags
}

# Created through the management plane (storage_account_id) so they still work
# after public network access is turned off.
resource "azurerm_storage_container" "raw" {
  name               = "raw-manifests"
  storage_account_id = azurerm_storage_account.solstice.id
}

resource "azurerm_storage_container" "processed" {
  name               = "processed"
  storage_account_id = azurerm_storage_account.solstice.id
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.solstice.id

  rule {
    name    = "tier-and-expire-raw-manifests"
    enabled = true

    filters {
      prefix_match = ["raw-manifests/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        tier_to_cold_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than       = 365
      }
    }
  }
}

# Client Success (Lab 01 group) can read processed output, nothing else
resource "azurerm_role_assignment" "client_success_processed" {
  scope                = azurerm_storage_container.processed.resource_manager_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_group.client_success.object_id
  principal_type       = "Group"
}

# ---------- Private connectivity ----------
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.data.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "prod" {
  name                  = "link-vnet-solstice-prod"
  resource_group_name   = azurerm_resource_group.data.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.prod.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-stsolsticedata-blob"
  location            = local.location
  resource_group_name = azurerm_resource_group.data.name
  subnet_id           = azurerm_subnet.data.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-stsolsticedata"
    private_connection_resource_id = azurerm_storage_account.solstice.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
```

</details>

<details>
<summary><code>outputs.tf</code></summary>

```hcl
output "storage_account_name" {
  value = azurerm_storage_account.solstice.name
}

output "private_dns_zone_name" {
  value = azurerm_private_dns_zone.blob.name
}

output "prod_vnet_id" {
  value = azurerm_virtual_network.prod.id
}
```

</details>

### Terraform Workflow

```powershell
terraform init
terraform plan
terraform apply                                   # public access still on
# ...run the SAS upload test below...
terraform apply -var="lock_down_public_access=true"
```

<!-- Screenshot: terraform init / plan / apply / state list -->

## Verify

Create a few sample manifests and upload them with a container-scoped SAS (public access still on):

```powershell
$acct   = "stsolsticedata<suffix>"
$key    = az storage account keys list -g rg-solstice-data -n $acct --query "[0].value" -o tsv
$expiry = (Get-Date).ToUniversalTime().AddHours(2).ToString("yyyy-MM-ddTHH:mmZ")
$sas    = az storage container generate-sas --account-name $acct --account-key $key `
            --name raw-manifests --permissions cw --expiry $expiry --https-only -o tsv

New-Item -ItemType Directory -Force manifests | Out-Null
1..3 | ForEach-Object {
  "store_id,date,sales`n101,2026-10-0$_,1520.40`n102,2026-10-0$_,980.15" | Set-Content "manifests\pos-$_.csv"
}
azcopy copy "manifests\*.csv" "https://$acct.blob.core.windows.net/raw-manifests?$sas"
```

Then lock the account down and confirm:

1. **Re-run the AzCopy command.** It now fails with `AuthorizationFailure` (403). The SAS is valid, but the network path is closed.
2. **Private endpoint:** Networking → Private endpoint connections shows `Approved`.
3. **Private DNS:** the zone has an A record for the account, linked to `vnet-solstice-prod`.
4. **From inside the network:** the name should resolve to a `10.1.2.x` address. You can't check that from your laptop yet. It is verified in Lab 04 from the ops VM and used by the Lab 03 batch job.

<!-- Screenshot: azcopy 403 after lockdown -->

The three manifests stay in `raw-manifests` for Lab 03 to process.

## Hands Off To Lab 03

Lab 03 builds directly on what exists now:

- the **prod VNet** gets two more subnets (`subnet-compute`, `subnet-batch`),
- the **batch job** reads the manifests you just uploaded and writes to `processed` over the private endpoint,
- `rg-solstice-network` is reused for the compute network resources.

Leave this lab applied.

## Teardown

Destroy Lab 02 **last**, after Labs 05, 04 and 03 are gone. Later labs add subnets, links and role assignments that depend on what this lab created, so destroying it early fails or strands them.

```powershell
terraform destroy
```

The DNS zone link must be deleted before the VNet; Terraform's dependency graph handles that, but if a destroy is interrupted you may need to re-run it. Lab 01 can be destroyed afterwards.

## Cost

RA-GZRS storage for a few KB of test data and a private endpoint (roughly a cent or two per hour) are the only meaningful charges. Run `terraform destroy` when finished with the series.
