#!/bin/sh

# Load variables from .env file
if [ -f $1 ]; then
    export $(cat $1 | grep -v '^#' | xargs)
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
    if
        ! command -v redis-cli &
        >/dev/null
    then
        echo "Redis is not installed."
        return
    fi

    # Get connected clients info if Redis is installed
    connected_clients=$(redis-cli info clients | grep "^connected_clients:" | awk -F':' '{print $2}' | tr -d '\r')
    echo "Redis connected clients: $connected_clients"
    if [ "$connected_clients" -ge 0 ]; then
        notify "Redis has $connected_clients connected clients"
    fi
}

notify "monitoring started"

while true; do
    check_disk_space
    check_redis_connected_clients
    sleep $SLEEP_TIME
done
