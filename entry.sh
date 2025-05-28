#!/bin/bash
set -e

echo "Waiting for MySQL to be available..."
TRIES=0
until mysql --host="$XI_NETWORK_SQL_HOST" --port="$XI_NETWORK_SQL_PORT" --user="$XI_NETWORK_SQL_LOGIN" --password="$XI_NETWORK_SQL_PASSWORD" "$XI_NETWORK_SQL_DATABASE" -e "SELECT 1 FROM zone_weather LIMIT 1"; do
    TRIES=$((TRIES+1))
    if [ "$TRIES" -ge 30 ]; then
        echo "MySQL did not become available after 30 attempts. Exiting."
        exit 1
    fi
    echo "MySQL not ready yet... retrying ($TRIES)"
    sleep 5
done

if [ "${TARGET_BIN}" = "xi_connect" ]; then
    mysql --host=$XI_NETWORK_SQL_HOST --port=$XI_NETWORK_SQL_PORT --user=$XI_NETWORK_SQL_LOGIN --password=$XI_NETWORK_SQL_PASSWORD $XI_NETWORK_SQL_DATABASE -e "UPDATE zone_settings set zoneip='$XI_NETWORK_ZONE_IP'"
    python3 ./tools/dbtool.py update || true
fi

exec "/server/${TARGET_BIN}"