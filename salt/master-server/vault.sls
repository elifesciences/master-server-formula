{% set vault_version = '0.11.0' %}
{% set vault_hash = 'ca9316e4864a9585f7c6507e38568053' %}
{% set vault_archive = 'vault_' + vault_version + '_linux_amd64.zip' %}
vault-binary:
    file.managed:
        - name: /root/{{ vault_archive }}
        - source: https://releases.hashicorp.com/vault/{{ vault_version }}/{{ vault_archive }}
        - source_hash: md5={{ vault_hash }}

    archive.extracted:
        - name: /opt/vault/
        - source: /root/{{ vault_archive }}
        - enforce_toplevel: False
        - require:
            - file: vault-binary

vault-symlink:
    file.symlink:
        - name: /usr/local/bin/vault
        - target: /opt/vault/vault
        - require:
            - vault-binary

vault-user:
    user.present: 
        - name: vault
        - groups:
            - vault
        - shell: /bin/false

vault-folder:
    file.directory:
        - name: /var/lib/vault
        - user: vault
        - group: vault
        - mode: 750
        - require:
            - vault-user

vault-configuration:
    file.managed:
        - name: /etc/vault.hcl 
        - source: salt://master-server/config/etc-vault.hcl
        - template: jinja
        - user: vault
        - group: vault
        - mode: 640
        - require:
            - vault-user

vault-systemd:
    file.managed:
        - name: /lib/systemd/system/vault.service
        - source: salt://master-server/config/lib-systemd-system-vault.service
        - template: jinja
        - require:
            - vault-binary
            - vault-symlink
            - vault-folder
            - vault-configuration

    cmd.run:
        - name: systemctl daemon-reload
        - require:
            - file: vault-systemd

    service.running:
        - name: vault
        - enable: True
        - require:
            - cmd: vault-systemd
        # restart vault service when certificates change
        # certificates not present in dev environments
        {% if pillar.elife.env != 'dev' %}
        - onchanges:
            # the two files references in /etc/vault.hcl
            # they're only modified when the certificate is regenerated
            - web-fullchain-key
            - web-private-key
        {% endif %}

{% if pillar.elife.env != 'dev' %}
{% set vault_addr = 'https://' + salt['elife.cfg']('cfn.outputs.DomainName') + ':8200' %}
{% else %}
{% set vault_addr = 'http://localhost:8200' %}
{% endif %}
vault-cli-client-environment-configuration:
    file.managed:
        - name: /etc/profile.d/vault-client.sh
        - contents: export VAULT_ADDR={{ vault_addr }}
        - template: jinja
        - mode: 644

    environ.setenv:
        - name: VAULT_ADDR
        - value: {{ vault_addr }}

# vault initialization requires a human, so the only thing we
# can check on the first highstate is that a daemon is listening
vault-bootstrap-smoke-test:
    cmd.run:
        - name: wait_for_port 8200 10
        - runas: {{ pillar.elife.deploy_user.username }}

vault-backup:
    file.managed:
        - name: /etc/ubr/vault-backup.yaml
        - source: salt://master-server/config/etc-ubr-vault-backup.yaml
        - makedirs: True
        - require:
            - install-ubr

{% set vault_init_log = '/home/' ~ pillar.elife.deploy_user.username ~ '/vault-init.log' %}

vault-init:
    cmd.run:
        - name: vault operator init -key-shares=1 -key-threshold=1 > {{ vault_init_log }}
        - unless:
            - test -d /var/lib/vault/core
        - require:
            - vault-bootstrap-smoke-test

vault-unseal:
    cmd.run:
        - name: | 
            grep Unseal {{ vault_init_log }} | sed -e 's/.*: //g' > /tmp/vault-unseal-key.log
            bash -c 'vault operator unseal $(cat /tmp/vault-unseal-key.log)'
            rm /tmp/vault-unseal-key.log
        - runas: {{ pillar.elife.deploy_user.username }}
        - onlyif:
            - test -e {{ vault_init_log }}
        - unless:
            - vault status
        - require:
            - vault-init

vault-status-smoke-test:
    cmd.run:
        - name: vault status
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - vault-unseal

vault-root-token:
    cmd.run:
        - name: |
            grep "Initial Root Token" {{ vault_init_log }} | sed -e 's/.*: //g' > /home/{{ pillar.elife.deploy_user.username }}/.vault-token
        - runas: {{ pillar.elife.deploy_user.username }}
        - creates: /home/{{ pillar.elife.deploy_user.username }}/.vault-token
        - require:
            - vault-status-smoke-test

vault-token-smoke-test:
    cmd.run:
        - name: |
            vault token lookup > /dev/null
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - vault-root-token

vault-secret-key-value-store:
    cmd.run:
        - name: vault kv enable-versioning secret/
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - vault-token-smoke-test

vault-policies:
    file.recurse:
        - name: /home/{{ pillar.elife.deploy_user.username }}/vault-policies/
        - source: salt://master-server/vault-policies/
        - runas: {{ pillar.elife.deploy_user.username }}
        - file_mode: 444
        - require:
            - vault-token-smoke-test

vault-file-audit-enabled:
    file.managed:
        - name: /var/log/vault_audit.log
        # vault tries to chmod the file to manage it itself, write permissions are not enough, it must also be owner:
        # - https://groups.google.com/g/vault-tool/c/XMiK3fKG-eA
        - user: vault
        - group: vault
        - mode: 664
        - require:
            - vault-user

    cmd.run:
        - name: vault audit enable file file_path=/var/log/vault_audit.log
        - runas:  {{ pillar.elife.deploy_user.username }}
        - require:
            - file: vault-file-audit-enabled
            - vault-token-smoke-test
