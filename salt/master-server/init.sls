# every 60 seconds
master-server-maintenance:
    cron.present:
        - identifier: master-server-maintenance
        - name: cd /opt/builder/scripts && ./update-master.sh
        - minute: * # every minute
        - onlyif:
            - test -d /opt/builder/
