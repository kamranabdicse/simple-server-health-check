#!/bin/sh

# Load variables from .env file
if [ -f "$(dirname "$0")/.env" ]; then
    export $(cat "$(dirname "$0")/.env" | grep -v '^#' | xargs)
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

notify "$1"
