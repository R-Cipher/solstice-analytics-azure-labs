# Lab 04 — Study Notes
**AZ-104 Domain:** Implement and manage virtual networking (15–20%)

These notes map Lab 04 to AZ-104 sub-skills. They are kept out of the lab README so the README stays focused on the project.

## What this lab exercises

| Exam sub-skill | Where it shows up in this lab |
|---|---|
| VNet design and IP addressing | Non-overlapping 10.0 / 10.1 / 10.2 address spaces, which is what makes peering possible |
| VNet peering | Two peering resources per pair (hub-to-prod and prod-to-hub, hub-to-dev and dev-to-hub), with "allow forwarded traffic" and gateway transit left off |
| NSGs | Subnet-level NSGs, unique rule priorities, evaluation order, a custom deny-all at 4096 that overrides the default rules, and adding rules to an NSG another lab owns |
| NAT gateway | Subnet-level outbound with a Standard static public IP, one gateway per VNet, taking over from a load balancer's default SNAT |
| Default outbound access | Turning off the implicit outbound IP Azure gives subnets with no NAT gateway, public IP or load balancer |
| Load balancer health probes | The probe source (`AzureLoadBalancer` service tag) and the probe port must be allowed through the NSG |
| Private DNS and private endpoints | Linking the zone to every VNet that needs to resolve the endpoint (prod in Lab 02, the hub here); NSGs applying to a private endpoint |
| Virtual machines (supporting) | A private VM with no public IP, managed through Run Command, with a system-assigned identity |
| Connectivity troubleshooting | Proving reachability and isolation from inside the network, testing both allowed and blocked ports |

## Key concept to know cold

VNet peering is **not transitive**. If the hub peers with prod and with dev, prod and dev still can't talk to each other through the hub unless you add routing (a UDR pointing to an NVA or Azure Firewall in the hub) and enable forwarded traffic on the peerings. The exam loves testing this misconception.

## Second concept: default rules vs. a default-deny

Every NSG gets built-in inbound rules you can't delete: `AllowVnetInBound` (65000), `AllowAzureLoadBalancerInBound` (65001), and `DenyAllInBound` (65500). The first two are broader than they look. `AllowVnetInBound` includes peered address spaces, so every peered network can reach every port by default. A custom deny-all at a priority *below* 65000 (this lab uses 4096) runs first, so anything you haven't explicitly allowed is blocked. The catch: the load balancer's probe comes from `AzureLoadBalancer`, which is allowed by the 65001 rule. A deny-all above that rule blocks the probe too, so you need an explicit allow for the probe port above the deny.

## Related facts worth remembering

- A peering is **one-directional**. Each side needs its own peering, and traffic flows only when both show *Connected*. The portal creates both sides in one step; Terraform needs two resources.
- Peered VNets **can't have overlapping address spaces**.
- A NAT gateway attaches to **subnets in its own VNet** only. It can use up to 16 public IPs or prefixes. A **UDR can't target a NAT gateway** as a next hop; it takes effect as soon as it's associated with a subnet.
- A NAT gateway takes precedence over a Standard load balancer's outbound rules and default SNAT for a subnet that has both. Inbound through the load balancer is unaffected.
- A Standard NAT gateway is **zonal or no-zone**, not zone-redundant. Zone-resilient outbound needs a gateway per zone.
- **NSG rule priorities must be unique within one NSG.** Azure rejects a duplicate, even across two separate rule resources. Custom rules use 100–4096, and a lower number wins. A rule can't go below 100, even if you want it to run before another rule. In this lab, a probe allow that had to run ahead of the 4096 deny but couldn't share Lab 03's 100 landed on 105: unique, in range, and above the deny.
- A subnet with no NAT gateway, public IP or load balancer still gets **default outbound access** through an implicit Microsoft-owned IP. Setting `default_outbound_access_enabled = false` removes it. Microsoft recommends an explicit outbound method (NAT gateway) and turning the default off for new subnets.
- A Standard load balancer's health probe comes from the `AzureLoadBalancer` service tag, not from the internet. The probe port must match the load balancer's probe configuration, and the NSG must allow that port.
- The `VirtualNetwork` service tag includes peered address spaces, so an allow for `VirtualNetwork` lets a peered VNet in on any port unless a higher-priority rule blocks it.
- NSGs only apply to private endpoints when the subnet's **private endpoint network policy** is enabled (Lab 02 enabled it on `subnet-data`).
- A private DNS zone only resolves for VNets it is **linked** to. Linking it to the hub doesn't make it resolve in spokes.
- An NSG's deny doesn't stop a VM from having a route. The NSG controls the network path; access to the VM still depends on the SSH key and user, which the NSG can't check.
