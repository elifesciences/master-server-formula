{% set vault_version = '0.10.1' %}
{% set vault_hash = 'f53ccc280650fed38a10e08c31565e9e' %}
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
        - require:
            - cmd: vault-systemd

{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
{% set vault_addr = 'https://$(hostname):8200' %}
{% else %}
{% set vault_addr = 'http://localhost:8200' %}
{% endif %}
vault-cli-client-environment-configuration:
    file.managed:
        - name: /etc/profile.d/vault-client.sh
        - contents: export VAULT_ADDR={{ vault_addr }}
        - template: jinja
        - mode: 644

# smoke test fails if `vault operator init` has not been run
# have to find another smoke test, as that operation outputs sensitive unseal keys and master tokens that a human needs to collect
vault-smoke-test:
    cmd.run:
        - name: vault status | grep Sealed
        - user: {{ pillar.elife.deploy_user.username }}

vault-backup:
    file.managed:
        - name: /etc/ubr/vault-backup.yaml
        - source: salt://master-server/config/etc-ubr-vault-backup.yaml
        - makedirs: True
        - require:
            - install-ubr
