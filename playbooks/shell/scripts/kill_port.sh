#!/usr/bin/env bash
# Usage: kill_port <port> [signal]
port=$1
signal=${2:-TERM}
if [ -z "$port" ]; then
    echo "Usage: kill_port <port> [signal]"
    exit 1
fi

pid=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1)
if [ -z "$pid" ]; then
    pid=$(lsof -iTCP:"$port" -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2{print $2}')
fi
if [ -z "$pid" ]; then
    echo "No process listening on port $port."
    exit 1
fi

echo "Killing PID $pid (port $port) with SIG$signal..."
kill -"$signal" "$pid"
