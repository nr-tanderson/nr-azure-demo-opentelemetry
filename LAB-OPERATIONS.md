# Payment lab infrastructure operations

Application workshop, code-fix instructions and New Relic queries are in the separate ReliBank checkout at `/Users/tanderson/Documents/newrelic/relibank/demo_lab/README.md`. No application source is nested in this repo.

## Infrastructure ownership

- `infra/` owns AKS, generation identity, and cluster/registry role assignments. The bootstrap-owned demo resource group remains empty after teardown so its scoped deployment permissions survive rebuilds.
- `scripts/bootstrap-state.sh` creates the persistent demo and state/artifact resource groups, state account/container, and Basic ACR. It is a one-time, billable Azure operation; run only after reviewing subscription and names. Set `DEMO_RESOURCE_GROUP` to `rg-<name_prefix>` if not using the default. It applies `OWNER=TANDERSON` to taggable resources.
- Set repo variable `LAB_ACR_NAME` to the registry printed by bootstrap. `infra/` reads this existing registry; it does NOT own or destroy it.
- Both repos use the same backend variables and the same `.connection.json` and `.operation-lock` blob names derived from `TFSTATE_KEY`.

## Required protections before running

Restrict GitHub environments `lab-infrastructure` and `lab-node-access` to `main`; this lab intentionally has no required environment reviewers. Keep PR review protection on the infra `main` branch. Configure Azure OIDC for the main branch (plan job) AND both environments (apply and finalize jobs). A user-assigned managed identity works without Entra application-registration permission. The app repo needs its own environment OIDC subject and shares the same deployer principal or equivalent explicit permissions.

Use the previously documented Azure secrets/backend variables plus `LAB_ACR_NAME`. Keep identity identifiers used by the plan job at repository scope. No client secret is needed. Grant the deployment identity:

- Contributor and Role Based Access Control Administrator on the bootstrap-owned demo resource group only.
- Reader on the persistent state/artifact resource group, Storage Blob Data Contributor on the state account, and Role Based Access Control Administrator on the registry. Terraform grants AcrPush on that registry.
- After AKS provisioning, Reader and Tag Contributor on its exact managed node resource group. The apply summary prints the two commands for the signed-in Azure owner. If finalization runs before those grants exist, run the commands and dispatch Build again to complete tagging and activate the handoff. Repeat the grants after destroy/rebuild if Azure removed the node resource group and its scoped role assignments.

Do not grant subscription-wide Contributor or Owner to the deployment identity. An Azure owner must register required resource providers during bootstrap; Terraform auto-registration is disabled. State and plan artifacts can contain sensitive metadata; do not expose artifacts outside authorized reviewers. Plan artifacts expire after one day.

## Workflow order

1. Build AKS: manually dispatch -> save plan -> apply the exact saved plan -> publish provisioned handoff -> ensure the node-group roles listed in the summary exist -> tag resources and publish active handoff with generation UUID. If finalization failed before the role grants were added, dispatch Build again after adding them.
2. Select exactly one app repo and run its manual deploy workflow. ReliBank, OTel Astronomy Shop, and PetClinic each have their own local source checkout and deployment workflow; all read the active handoff, validate generation, and acquire the shared blob lease. No hardcoded public IP survives a rebuild.
3. Uninstall the selected app or pause ReliBank's lab before destroying infrastructure. Destroy AKS: provide typed confirmation -> save plan -> acquire shared lease -> publish paused state -> suspend ReliBank schedules -> apply exact destroy plan -> publish destroyed state.

After destroy, the persistent registry and storage remain billable and retain the baseline/fixed images and Terraform state. The empty bootstrap-owned demo resource group and deployment identity also remain. Deleting those is a different, permanent cleanup step. Rebuild then reset to the saved baseline digest to repeat the demo; do not reset Git history.

The operation lock prevents simultaneous use by the ReliBank lab, Astronomy Shop, PetClinic, and reviewed-infra workflows. The ReliBank payment workflow is a synthetic code-fix exercise, not the full ReliBank banking UI.

New Relic is intentionally not configured yet. The ReliBank payment workflow defaults monitoring off and uses only fresh `LAB_NR_*` secrets after explicit opt-in. The Astronomy Shop workflow also has a default-off monitoring input. No existing New Relic key is read by either lab path.

The shared AKS cluster, OIDC federation, state backend, registry, tags, and handoff are configured in Azure. The full ReliBank UI/API deployment is a separate manual workflow and must pass its image, database, and health checks before the lab is considered ready. New Relic remains intentionally disabled.