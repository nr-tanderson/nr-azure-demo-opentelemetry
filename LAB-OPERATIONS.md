# Payment lab infrastructure operations

Application workshop, code-fix instructions and New Relic queries are in the separate ReliBank checkout at `/Users/tanderson/Documents/newrelic/relibank/demo_lab/README.md`. No application source is nested in this repo.

## Infrastructure ownership

- `infra/` owns AKS, its demo resource group, generation identity, and scoped role assignments.
- `scripts/bootstrap-state.sh` creates the persistent state/artifact resource group, state account/container, and Basic ACR. It is a one-time, billable Azure operation; run only after reviewing subscription and names. It applies `OWNER=TANDERSON` to taggable resources.
- Set repo variable `LAB_ACR_NAME` to the registry printed by bootstrap. `infra/` reads this existing registry; it does NOT own or destroy it.
- Both repos use the same backend variables and the same `.connection.json` and `.operation-lock` blob names derived from `TFSTATE_KEY`.

## Required protections before running

Create GitHub environment `lab-infrastructure`, restrict it to main and configure required reviewers. Protect main with PR review. The workflow's environment field alone does not enforce approval. Configure Azure OIDC for the main branch (plan job) AND environment (apply job). The app repo needs its own environment OIDC subject and shares the same deployer principal or equivalent explicit permissions.

Use the previously documented Azure secrets/backend variables plus `LAB_ACR_NAME`. Keep credentials used by the plan job at repository scope. Give the deployer blob data access on persistent storage, resource creation permissions for the lab, role-assignment permissions at the required scopes, and permission to read the persistent registry. State and plan artifacts can contain sensitive metadata; do not expose artifacts outside authorized reviewers. Plan artifacts expire after one day.

## Workflow order

1. Build AKS: save plan -> inspect run summary -> reviewer approval -> apply the exact saved plan -> publish active handoff with generation UUID.
2. Select exactly one app repo and run its manual deploy workflow. ReliBank, OTel Astronomy Shop, and PetClinic each have their own local source checkout and deployment workflow; all read the active handoff, validate generation, and acquire the shared blob lease. No hardcoded public IP survives a rebuild.
3. Uninstall the selected app or pause ReliBank's lab before destroying infrastructure. Destroy AKS: save plan -> inspect -> approval -> acquire shared lease -> publish paused state -> suspend ReliBank schedules -> apply exact destroy plan -> publish destroyed state.

After destroy, the persistent registry and storage remain billable and retain the baseline/fixed images and Terraform state. Deleting those is a different, permanent cleanup step. Rebuild then reset to the saved baseline digest to repeat the demo; do not reset Git history.

The operation lock prevents simultaneous use by the ReliBank lab, Astronomy Shop, PetClinic, and reviewed-infra workflows. The ReliBank payment workflow is a synthetic code-fix exercise, not the full ReliBank banking UI.

New Relic is intentionally not configured yet. The ReliBank payment workflow defaults monitoring off and uses only fresh `LAB_NR_*` secrets after explicit opt-in. The Astronomy Shop workflow also has a default-off monitoring input. No existing New Relic key is read by either lab path.

This setup has been statically validated and locally tested but not applied to Azure. GitHub protection settings, OIDC federation, required reviewers, registry setup, and a live deployment must be completed and verified before calling it an end-to-end lab.