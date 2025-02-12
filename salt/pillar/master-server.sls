elife:
    webserver:
        app: caddy
        auto_https: true
    certificates:
        username: vault

master_server:
    chemist:
        secret: null
    vault:
        dependent_projects:
            - basebox
