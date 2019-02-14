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

vault-token-master-server:
    cmd.run:
        - name: vault token create -policy=master-server -display-name={{ salt['grains.get']('id') }} -format=json | jq -r .auth.client_token > /tmp/.vault-token.master-server
        - user: {{ pillar.elife.deploy_user.username }}
        # TODO: do not execute on every highstate
        - require:
            - vault-policies-master-server


salt-vault-config-master.d:
    file.managed:
        - name: /etc/salt/master.d/vault.conf
        - source: salt://master-server/config/etc-salt-master.d-vault.conf
        - template: jinja
        - context:
            vault_addr: {{ vault_addr }}

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
        - context:
            vault_addr: {{ vault_addr }}
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

salt-vault-ext-pillars-minion.d:
    file.managed:
        - name: /etc/salt/minion.d/vault_ext_pillar.conf
        - source: salt://master-server/config/etc-salt-master.d-vault_ext_pillar.conf
        - template: jinja
        - context:
            vault_addr: {{ vault_addr }}
        - requires:
            - salt-extension-modules-elife_vault.py
{% endif %}
