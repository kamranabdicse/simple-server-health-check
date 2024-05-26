#!/bin/sh

# Load variables from .env file
if [ -f $1 ]; then
    export $(cat "$1" | grep -v '^#' | xargs)
fi

notify() {
    local message=$1
    curl --socks5 localhost:2080 \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$ADMIN_ID"
    echo ""
}

check_disk_space() {
    disk_space=$(df -h / | awk 'NR==2{sub(/%/, "", $5); print $5}')
    echo "Disk space usage: $disk_space, DISK_SPACE_THRESHOLD=$DISK_SPACE_THRESHOLD"
    if [ "$disk_space" -ge $DISK_SPACE_THRESHOLD ]; then
        notify "Disk space usage is $disk_space%"
    fi
}

check_redis_connected_clients() {
    # Check if redis-cli command exists
    if ! command -v redis-cli >/dev/null; then
        notify "Redis is not installed."
        return
    fi

    # Get connected clients info if Redis is installed
    connected_clients=$(redis-cli -a "$REDIS_PASSWORD" info clients | grep "^connected_clients:" | awk -F':' '{print $2}' | tr -d '\r')
    echo "Redis connected clients: $connected_clients"
    if [ "$connected_clients" -ge $REDIS_CONNECTION_THRESHOLD ]; then
        notify "Redis has $connected_clients connected clients"
    fi
}

check_postgres_connections() {
    # Get max_connections from postgresql.conf
    max_connections=$(grep -E "^\s*max_connections\s*=" /etc/postgresql/14/main/postgresql.conf | awk -F'=' '{print $2}' | awk '{print $1}')
    if [ -z "$max_connections" ]; then
        echo "Could not find max_connections in postgresql.conf"
        return
    fi
    export PGPASSWORD=$PGPASSWORD
    # Get the current number of connections from pg_stat_database
    current_connections=$(psql -U $PGUSER -d $POSTGRES_DB -t -c "SELECT sum(numbackends) FROM pg_stat_database;" | tr -d '[:space:]')
    if [ -z "$current_connections" ]; then
        echo "Could not get current connections from pg_stat_database"
        return
    fi
    echo $max_connections
    echo $PG_CONNECTION_THRESHOLD
    threshold=$(echo "$max_connections * $PG_CONNECTION_THRESHOLD" | bc)
    threshold=${threshold%.*}
    echo $threshold
    echo "PostgreSQL max connections: $max_connections, current connections: $current_connections, threshold: $threshold"
    if [ "$current_connections" -ge "$threshold" ]; then
        notify "PostgreSQL connections have reached $PG_CONNECTION_THRESHOLD of max $max_connections. Current connections: $current_connections"
    fi

}


while true; do
    check_disk_space
    check_redis_connected_clients
    check_postgres_connections

    sleep $SLEEP_TIME
done
