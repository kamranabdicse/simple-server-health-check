#!/bin/sh

SCRIPT_DIR=$(dirname "$0")
chmod +x "$SCRIPT_DIR/notify.sh"

# Load variables from .env file
if [ -f "$1" ]; then
    export $(cat "$1" | grep -v '^#' | xargs)
fi

notify() {
    message=$1
    $SCRIPT_DIR/notify.sh "$message"
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
    # Check if psql command exists
    if ! command -v psql >/dev/null; then
        notify "PostgreSQL is not installed."
        return
    fi

    # Determine PostgreSQL version
    postgres_version=$(psql -V | awk '{print $3}' | awk -F'.' '{print $1}')
    if [ -z "$postgres_version" ]; then
        notify "Could not determine PostgreSQL version."
        return
    fi

    # Get max_connections from postgresql.conf
    postgres_conf_path="/etc/postgresql/$postgres_version/main/postgresql.conf"
    if [ ! -f "$postgres_conf_path" ]; then
        notify "PostgreSQL configuration file not found at $postgres_conf_path"
        return
    fi

    max_connections=$(grep -E "^\s*max_connections\s*=" "$postgres_conf_path" | awk -F'=' '{print $2}' | awk '{print $1}')
    if [ -z "$max_connections" ]; then
        echo "Could not find max_connections in $postgres_conf_path"
        return
    fi

    export PGPASSWORD=$PGPASSWORD

    # Get the current number of connections from pg_stat_database
    current_connections=$(psql -U "$PGUSER" -d "$POSTGRES_DB" -t -c "SELECT sum(numbackends) FROM pg_stat_database;" | tr -d '[:space:]')
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


check_docker_logs() {
    if ! command -v docker >/dev/null; then
        notify "Docker is not installed."
        return
    fi

    container_id=$(docker ps -q -f "ancestor=$DOCKER_IMAGE_NAME")

    if [ -z "$container_id" ]; then
        notify "No container running for image: $DOCKER_IMAGE_NAME"
        return
    fi

    last_log_line=$(docker logs --tail 1 "$container_id" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
    
    if [ -z "$last_log_line" ]; then
        notify "No logs found for container: $container_id"
        return
    fi

    last_log_timestamp=$(date -d "$last_log_line" +%s)
    current_timestamp=$(date +%s)

    time_diff=$(( (current_timestamp - last_log_timestamp) / 60 ))

    echo "Last log timestamp: $last_log_line, Time difference: $time_diff hours"
    threshold_minutes=${INACTIVITY_THRESHOLD_MINUTES:-120}

    if [ "$time_diff" ge "$threshold_minutes" ]; then
        notify "Service has been inactive for over 5 mins. Last log at: $last_log_line"
    fi
}

while true; do
    check_disk_space
    check_redis_connected_clients
    check_postgres_connections
    check_docker_logs
    sleep $SLEEP_TIME
done
