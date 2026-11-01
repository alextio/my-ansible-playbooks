## k3s_server variables

`vault.yml` holds the encrypted secrets that `playbooks/k3s-argocd/secrets.yaml` turns into Kubernetes Secrets.

## Naming rule

Name every vault variable `<namespace>__<secret-name>` (double underscore, lowercase, hyphens allowed):

- `external-secrets__bitwarden-access-token` becomes Secret `bitwarden-access-token` in namespace `external-secrets`.
- The value is stored under the key in `k3s_secret_data_key` (`playbooks/k3s-argocd/vars.yml`, default `token`).
- The playbook discovers these variables by name, so adding a correctly named variable to the vault is all that is needed. Do not list Secrets in `vars.yml`.
- Namespaces are created by the playbook if missing.
- Because of the hyphens these names can't be used in `{{ }}` directly; reference them with `lookup('ansible.builtin.vars', name)`.
- Edit with `ansible-vault edit group_vars/k3s_server/vault.yml`; never write plaintext values to this directory.
