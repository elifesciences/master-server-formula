#!/bin/bash
# run as '{{ deploy_user }}'
# unseals Vault if sealed using the key found in '~/vault-init.log'.
set -e

vault_init_log="/home/{{ deploy_user }}/vault-init.log"

if vault status; then
    echo "already unsealed"
    exit 0
fi

if [ ! -e "$vault_init_log" ]; then
    echo "unseal key does not exist: $vault_init_log"
    exit 1
fi

grep "Unseal" "$vault_init_log" | sed -e 's/.*: //g' > /tmp/vault-unseal-key.log
vault operator unseal $(cat /tmp/vault-unseal-key.log)
rm /tmp/vault-unseal-key.log
