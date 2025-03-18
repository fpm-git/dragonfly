#!/bin/sh

# Exit immediately on any command error (fail fast)
set -e

HOST="localhost"
PORT=6379
KEY="healthcheck_key_$(date +%s%N)"
VALUE="ok"
PASSWORD=${DFLY_requirepass:-""}

REDIS_CLI_CMD="redis-cli -h $HOST -p $PORT"
if [ -n "$PASSWORD" ]; then
  REDIS_CLI_CMD="$REDIS_CLI_CMD -a $PASSWORD"
fi

ROLE=$($REDIS_CLI_CMD INFO REPLICATION | grep "role:" | cut -d":" -f2 | tr -d '\r')

if [ "$ROLE" = "master" ]; then
  # Master pod, perform full read/write check
  if [ "$($REDIS_CLI_CMD SET $KEY $VALUE NX EX 5)" != "OK" ]; then
    echo "Master pod healthcheck failed on SET operation."
    exit 1
  fi

  if [ "$($REDIS_CLI_CMD GET $KEY)" != "$VALUE" ]; then
    echo "Master pod healthcheck failed on GET operation."
    exit 1
  fi
else
  # Replica pod, perform basic ping check
  if [ "$($REDIS_CLI_CMD PING)" != "PONG" ]; then
    echo "Replica pod healthcheck failed on PING operation."
    exit 1
  fi
fi

exit 0