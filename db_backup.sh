#! /bin/sh

# db_backup.sh
# Dumps all databases on the local server to a directory and purge old backups

# Copyright 2023 Christian Baer
# http://github.com/chrisb86/

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

name=$(basename -- $0)

usage="Usage: ${name} sql|psql|redis [ -d DEST_DIR ] [ -k KEEP_DAYS ] [ -l LABEL ] [ - r REDIS_CONF_DIR ]"

# Show help screen
# Usage: help exitcode
help () {
  echo "${name}"
  echo
  echo "Dumps all databases on the local server to a directory and purge old backups"
  echo
  echo "${usage}"
  echo "  sql|psql|redis  Database type (mysql or postgresql)"
  echo "  - d             Destination directory (default: ./)"
  echo "  - k             Keep backups from n days (optional)"
  echo "  - l             Label for backup files (default: hostname)"
  echo "  - r             Where to look for redis configuration files (default: /usr/locl/etc)"
  exit $1
}

# Exit with errormessage
# Usage: exerr errormessage
exerr () { echo -e "$*" >&2 ; exit 1; }

# Run backup for (p)sql databases
# Usage: backup
backup () {
  for d in $databases; do
    timestamp=$(date +"%Y-%m-%d-%H%M%S")
    ${db_dump} ${db_dump_opts} ${d} | gzip -c > ${dest_dir}/${timestamp}_${label}_${d}.${suffix}.gz
  done
}

# Run backup for redis databases
# Usage: backup-redis
backup-redis () {
  redis_profiles=$(find ${redis_conf_dir}/redis-*.conf)

  for f in $redis_profiles; do

      redis_socket=$(cat ${f} | grep "unixsocket " | cut -d ' ' -f2)
      redis_password=$(cat ${f} | grep "requirepass " | cut -d ' ' -f2)
      redis_dir=$(cat ${f} | grep "dir " | cut -d ' ' -f2)
      redis_dumpfile=$(cat ${f} | grep "dbfilename " | cut -d ' ' -f2)

      timestamp=$(date +"%Y-%m-%d-%H%M%S")

      redis_timestamp_start=$(redis-cli -s ${redis_socket} -a ${redis_password} --no-auth-warning LASTSAVE)

      redis-cli -s ${redis_socket} -a ${redis_password} --no-auth-warning BGSAVE
      
      while [ $(redis-cli -s ${redis_socket} -a ${redis_password} --no-auth-warning LASTSAVE) -lt ${redis_timestamp_start} ]
      do
        sleep 1
      done
      gzip -c ${redis_dir}/${redis_dumpfile} > ${dest_dir}/${timestamp}_${label}_${redis_dumpfile}.gz
  done
}

# Purge files older than ${keep} days from destination directory
# Usage: cleanup
cleanup () {
  for d in $databases; do
    find ${dest_dir} -type f -name "*_${label}_${d}.${suffix}.gz" -mtime +${keep} -exec rm -r '{}' '+'
  done
}

case "$1" in
  help)
    help 0
  ;;
  psql)
    db_dump="pg_dump"
    db_dump_opts="-F p"
    suffix=psql
    ignore_list="postgres|template0|template1"
    databases=$(psql -q -A -t -c "SELECT datname FROM pg_database" | grep -Evw ${ignore_list})
  ;;
  sql)
    db_dump="mysqldump"
    db_dump_opts="--skip-extended-insert --set-gtid-purged=OFF --skip-comments --single-transaction"
    suffix="sql"
    ignore_list="mysql|information_schema|performance_schema|sys|test|log"
    databases=$(mysql -Bse 'show databases;' | grep -Evw ${ignore_list})
  ;;
  redis)
    backup_redis=true
  ;;
  *)
    help 1
  ;;
esac

shift; while getopts d:k:l:r: arg; do case ${arg} in
  d) DEST_DIR=${OPTARG};;
  k) keep=${OPTARG};;
  l) LABEL=${OPTARG};;
  r) REDIS=${OPTARG};;
  ?) exerr ${usage};;
  :) exerr ${usage};;
esac; done; shift $(( ${OPTIND} - 1 ))

dest_dir="${DEST_DIR:-./}"
label="${LABEL:-$(hostname)}"
redis_conf_dir="${REDIS:-/usr/local/etc}"

if [ -n "${backup_redis}" ]; then
  backup-redis
else
  backup
fi

if [ -n "${keep+set}" ]; then
  cleanup
fi