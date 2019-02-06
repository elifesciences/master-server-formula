{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
    {% set vault_addr = 'https://$(hostname):8200' %}
{% else %}
    {% set vault_addr = 'http://localhost:8200' %}
{% endif %}

salt-vault-config:
    file.managed:
        - name: /etc/salt/master.d/vault.conf
        - source: salt://master-server/config/etc-salt-master.d-vault.conf
        - template: jinja
        - defaults:
            vault_addr: {{ vault_addr }}

salt-vault-peer-runner-conf:
    file.managed:
        - name: /etc/salt/master.d/peer_run.conf
        - source: salt://master-server/config/etc-salt-master.d-peer_run.conf

salt-vault-ext-pillars:
    file.managed:
        - name: /etc/salt/master.d/vault_ext_pillar.conf
        - source: salt://master-server/config/etc-salt-master.d-vault_ext_pillar.conf
