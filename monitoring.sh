#!/bin/sh

# Load variables from .env file
if [ -f "$1" ]; then
    export $(cat "$1" | grep -v '^#' | xargs)
fi

build_curl_command() {
    url=$1
    shift
    data=$@
    if [ -n "$SOCKS5_PROXY" ]; then
        echo "curl --socks5 $SOCKS5_PROXY --data-urlencode \"$data\" \"$url\""
    else
        echo "curl --data-urlencode \"$data\" \"$url\""
    fi
}

notify() {
    message=$1
    url="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$ADMIN_ID"
    data="text=$message"
    eval $(build_curl_command "$url" "$data")
    echo ""
}

check_disk_space() {
    disk_space=$(df -h / | awk 'NR==2{sub(/%/, "", $5); print $5}')
    echo "Disk space usage: $disk_space, DISK_SPACE_THRESHOLD_PERCENTAGE: $DISK_SPACE_THRESHOLD_PERCENTAGE"
    if [ "$disk_space" -ge "$DISK_SPACE_THRESHOLD_PERCENTAGE" ]; then
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
    maxclients=$(redis-cli -a "$REDIS_PASSWORD" config get maxclients | awk 'NR==2')
    echo "Redis connected clients: $connected_clients, max clients: $maxclients"
    
    threshold=$(echo "$maxclients * $REDIS_CONNECTION_THRESHOLD_PERCENTAGE" | bc)
    threshold=${threshold%.*}
    echo "Redis max clients: $maxclients, current connected clients: $connected_clients, threshold: $threshold"
    
    if [ "$connected_clients" -ge "$threshold" ]; then
        notify "Redis connections have reached $REDIS_CONNECTION_THRESHOLD_PERCENTAGE of max $maxclients. Current connections: $connected_clients"
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
    threshold=$(echo "$max_connections * $PG_CONNECTION_THRESHOLD_PERCENTAGE" | bc)
    threshold=${threshold%.*}
    echo "PostgreSQL max connections: $max_connections, current connections: $current_connections, threshold: $threshold"
    if [ "$current_connections" -ge "$threshold" ]; then
        notify "PostgreSQL connections have reached $PG_CONNECTION_THRESHOLD_PERCENTAGE of max $max_connections. Current connections: $current_connections"
    fi
}

while true; do
    check_disk_space
    check_redis_connected_clients
    check_postgres_connections

    sleep $SLEEP_TIME
done
