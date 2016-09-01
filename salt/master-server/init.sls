# every 60 seconds
master-server-maintenance:
    cron.present:
        - identifier: master-server-maintenance
        - name: cd /opt/builder/scripts && ./update-master.sh
        - minute: '*' # every minute
        - onlyif:
            - test -d /opt/builder/

chemist-repository:
    builder.git_latest:
        - name: git@github.com:elifesciences/chemist.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: master
        - branch: master
        - target: /opt/chemist/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - fetch_pull_requests: True
    
    file.directory:
        - name: /opt/chemist
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - builder: chemist-repository

    cmd.run:
        - name: ./install.sh
        - cwd: /opt/chemist
        - user: {{ pillar.elife.deploy_user.username }}

# intentionally owned by root as it contains a remotely executable command
chemist-configuration:
    file.managed:
        - name: /opt/chemist
        - mode: 644
        - source:  salt://master-server/config/opt-chemist-app.conf
        - require:
            - chemist-repository

chemist-service:
    file.managed:
        - name: /etc/init/chemist.conf
        - source: salt://master-server/config/etc-init-chemist.conf
        - template: jinja
        - require:
            - chemist-repository

chemist-service-start:
    cmd.run:
        - name: |
            stop chemist || echo "chemist was not running"
            start chemist
        - require:
            - chemist-service
