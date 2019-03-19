{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
    {% set vault_addr = 'https://' + salt['elife.cfg']('cfn.outputs.DomainName') + ':8200' %}
{% else %}
    {% set vault_addr = 'http://localhost:8200' %}
{% endif %}

# salt-vault.sls: create master-server token
# salt-vault.sls: put master-server-token in right configuration

vault-policies-master-server:
    cmd.run:
        - name: vault policy write master-server master-server.hcl
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /home/{{ pillar.elife.deploy_user.username }}/vault-policies/
        - require:
            - vault-policies

{% set master_server_token_path = '/home/' ~ pillar.elife.deploy_user.username ~ '/.vault-token.master-server' %}
{% set vault_token_period = '48h' %}

vault-token-master-server:
    cmd.run:
        - name: vault token create -policy=master-server -display-name={{ salt['grains.get']('id') }} -period={{ vault_token_period }} -format=json | jq -r .auth.client_token > {{ master_server_token_path }}
        - user: {{ pillar.elife.deploy_user.username }}
        - creates: {{ master_server_token_path }}
        - require:
            - vault-policies-master-server

vault-token-master-server-renewal:
    cron.present:
        - identifier: vault-token-master-server-renewal
        - name: bash -c "VAULT_ADDR={{ vault_addr }} VAULT_TOKEN=$(cat {{ master_server_token_path }}) vault token renew"
        - minute: random
        - require:
            - vault-token-master-server

salt-vault-config-master.d:
    file.managed:
        - name: /etc/salt/master.d/vault.conf
        - source: salt://master-server/config/etc-salt-master.d-vault.conf
        - template: jinja
        - onlyif:
            - test -e /tmp/.vault-token.master-server
        - context:
            vault_addr: {{ vault_addr }}
            master_server_token_path: {{ master_server_token_path }}

salt-extension-modules-elife_vault.py:
    file.managed:
        - name: /opt/salt-extension-modules/pillar/elife_vault.py
        - source: salt://master-server/config/opt-salt-extension-modules-pillar-elife_vault.py
        - makedirs: True

salt-vault-ext-pillars-master.d:
    file.managed:
        - name: /etc/salt/master.d/vault_ext_pillar.conf
        - source: salt://master-server/config/etc-salt-master.d-vault_ext_pillar.conf
        - template: jinja
        - requires:
            - salt-extension-modules-elife_vault.py

# provide Vagrant and masterless instances with a connection to their own Vault
{% if pillar.elife.env in ['dev', 'ci'] %}
salt-vault-config-minion.d:
    file.managed:
        - name: /etc/salt/minion.d/vault.conf
        - source: salt://master-server/config/etc-salt-master.d-vault.conf
        - template: jinja
        - context:
            vault_addr: {{ vault_addr }}
            master_server_token_path: {{ master_server_token_path }}

salt-vault-ext-pillars-minion.d:
    file.managed:
        - name: /etc/salt/minion.d/vault_ext_pillar.conf
        - source: salt://master-server/config/etc-salt-master.d-vault_ext_pillar.conf
        - template: jinja
        - requires:
            - salt-extension-modules-elife_vault.py
{% endif %}
