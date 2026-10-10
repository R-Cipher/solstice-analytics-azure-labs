# Lab 03 — Study Notes
**AZ-104 Domain:** Deploy and manage Azure compute resources (20–25%)

These notes map Lab 03 to AZ-104 sub-skills. They are kept out of the lab README so the README stays focused on the project.

## What this lab exercises

| Exam sub-skill | Where it shows up in this lab |
|---|---|
| VM sizing and availability | Choosing a zonal `Standard_D2nlds_v6` scale set (`Standard_B2s` wasn't available in this subscription) and understanding Availability Zones vs. Availability Sets |
| VMSS and autoscale | Scale-out and scale-in rules based on a metric threshold, min/max/default capacity |
| Load balancing | Standard LB, health probe, backend pool, rule; Standard LBs are closed until an NSG allows traffic |
| Containers | ACR image build with `az acr build` (ACR Tasks), ACI deployment into a VNet, ACI vs. AKS scope |
| Managed identity | User-assigned identity with container-scoped RBAC on storage (Reader on `raw-manifests`, Contributor on `processed`) instead of keys |
| App Service | Plans and tiers (B1 here; deployment slots need Standard or higher), when PaaS beats IaaS |

## Key concept to know cold

Availability **Zones** protect against a datacenter-level failure inside a region (physically separate facilities). Availability **Sets** protect against rack-level failures inside one datacenter (fault and update domains). A VMSS can span zones, but not every VM size supports every zone in every region, so always check SKU availability. In this lab the size had to change from `Standard_B2s` to `Standard_D2nlds_v6` for exactly that reason.

## Related facts worth remembering

- A **Standard** load balancer and Standard public IP are secure by default: inbound traffic is blocked until an NSG allows it. A Basic one is open by default.
- Standard LB rules provide **outbound SNAT** for backend instances; a NAT gateway on the subnet overrides that (Lab 04).
- A **user-assigned** identity exists independently and can be attached to many resources; a **system-assigned** identity lives and dies with its resource.
- A subnet used by ACI must be **delegated** to `Microsoft.ContainerInstance/containerGroups` and can't host other resource types.
- A container group with an IP address (including a private one in a VNet) must declare ports, both on the group (`exposed_port`) and on a container (`ports`), even if the job never listens on one.
- A VMSS can report **Provisioning succeeded** while cloud-init failed (for example, packages that couldn't download). Check the instance view or cloud-init logs, not just the deployment state.
- Autoscale needs both a scale-out and a scale-in rule, and a cooldown so the instance count doesn't flap.
