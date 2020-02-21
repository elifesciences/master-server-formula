master-server-maintenance:
    cron.present:
        - identifier: master-server-maintenance
        - name: /opt/update-master.sh
        - minute: 0
        - hour: '*' # every hour

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
        - runas: {{ pillar.elife.deploy_user.username }}

# intentionally owned by root as it contains a remotely executable command
chemist-configuration:
    file.managed:
        - name: /opt/chemist/app.cfg
        - mode: 644
        - user: root
        - source:  salt://master-server/config/opt-chemist-app.conf
        - template: jinja
        - require:
            - chemist-repository

chemist-service-upstart:
    file.managed:
        - name: /etc/init/chemist.conf
        - source: salt://master-server/config/etc-init-chemist.conf
        - template: jinja

chemist-service-systemd:
    file.managed:
        - name: /lib/systemd/system/chemist.service
        - source: salt://master-server/config/lib-systemd-system-chemist.service
        - template: jinja

chemist-service-start:
    {% if salt['grains.get']('oscodename') == 'trusty' %}
    cmd.run:
        - name: |
            stop chemist || echo "chemist was not running"
            start chemist
    {% else %}
    cmd.run:
        - name: |
            systemctl stop chemist || echo "chemist was not running"
            systemctl start chemist
    {% endif %}
        - require:
            - chemist-repository
            - chemist-service-upstart
            - chemist-service-systemd
