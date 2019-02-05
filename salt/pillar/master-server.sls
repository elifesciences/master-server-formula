elife:
    certificates:
        username: vault

master_server:
    vault:
        access_token: 11111111-2222-3333-4444-555555555555
        # do not use `root`: Vault has more secrets than Salt needs
        policy: master-server
    chemist:
        secret: null
