_db_backup_ dumps all mysql, postgresql or redis databases on the local server to a directory and purge old backups.

```
Usage: db_backup sql|psql|redis [ -d DEST_DIR ] [ -k KEEP_DAYS ] [ -l LABEL ] [ - r REDIS_CONF_DIR ]
  sql|psql|redis  Database type (mysql or postgresql)
  - d             Destination directory (default: ./)
  - k             Keep backups from n days (optional)
  - l             Label for backup files (default: hostname)
  - r             Where to look for redis configuration files (default: /usr/locl/etc)
```

To backup eg all postgresql databases to /var/db/backups/postgres and keep backups for five days run ```db_backup psql -d /var/db/backups/postgres -k 5```.
To backup eg all redis databases to /var/db/backups/redis and keep backups for 10 days run ```db_backup redis -d /var/db/backups/redis -k 10 -r /usr/local/etc```.

There is no credential managing implmented and it is assumed, that the current user is able to connect to the server and list and dump the databases.

For redis backups the script parses to configured profiles by lokking for redis-*.conf files in /usr/lkocal/etc. It extracts the password and connects to the socket.