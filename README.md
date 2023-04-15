_db_backup_ dumps all mysql or postgresql databases on the local server to a directory and purge old backups.

```
Usage: db_backup sql|psql [ -d DEST_DIR ] [ -k KEEP_DAYS ] [ -l LABEL ]
  sql|psql  Database type (mysql or postgresql)
  - d       Destination directory (default: ./)
  - k       Keep backups from n days (optional)
  - l       Label for backup files (default: hostname)
```

To backup eg all postgresql databases to /var/db/backups/postgres and keep backups for five days run ```db_backup psql -d /var/db/backups/postgres -k 5```.

There is no credential managing implmented and it is assumed, that the current user is able to connect to the server and list and dump the databases.