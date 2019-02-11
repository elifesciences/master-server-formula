{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
    {% set vault_addr = 'https://' + grains['localhost'] + ':8200' %}
{% else %}
    {% set vault_addr = 'http://localhost:8200' %}
{% endif %}

salt-extension-modules-elife_vault.py:
    file.managed:
        - name: /opt/salt-extension-modules/pillar/elife_vault.py
        - source: salt://master-server/config/opt-salt-extension-modules-pillar-elife_vault.py
        - makedirs: True

# configure the minion too when testing master-server--dev
{% if pillar.elife.env == 'dev' %}
{% set configurations = ['master.d', 'minion.d'] %}
{% else %}
{% set configurations = ['master.d'] %}
{% endif %}

{% for configuration in configurations %}
salt-vault-config-{{ configuration }}:
    file.managed:
        - name: /etc/salt/{{ configuration }}/vault.conf
        - source: salt://master-server/config/etc-salt-master.d-vault.conf
        - template: jinja
        - context:
            vault_addr: {{ vault_addr }}

salt-vault-peer-runner-conf-{{ configuration }}:
    file.managed:
        - name: /etc/salt/{{ configuration }}/peer_run.conf
        - source: salt://master-server/config/etc-salt-master.d-peer_run.conf

salt-vault-ext-pillars-{{ configuration }}:
    file.managed:
        - name: /etc/salt/{{ configuration }}/vault_ext_pillar.conf
        - source: salt://master-server/config/etc-salt-master.d-vault_ext_pillar.conf
        - template: jinja
        - context:
            vault_addr: {{ vault_addr }}
        - requires:
            - salt-extension-modules-elife_vault.py
{% endfor %}
