salt-vault-config:
    file.managed:
        - name: /etc/salt/master.d/vault.conf
        - source: salt://master-server/config/etc-salt-master.d-vault.conf
        - watch_in:
            - service: vault-systemd

salt-vault-peer-runner-conf:
    file.managed:
        - name: /etc/salt/master.d/peer_run.conf
        - source: salt://master-server/config/etc-salt-master.d-peer_run.conf
        - watch_in:
            - service: vault-systemd
