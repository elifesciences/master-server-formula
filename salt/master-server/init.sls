builder-present:
    file.present:
        - name: /opt/builder/bldr

# every 60 seconds
master-server-maintenance:
    cron.present:
        - identifier: master-server-maintenance
        - name: cd /opt/builder/scripts && ./update-master.sh
        - minute: 1
        - require:
            - file: builder-present
