#!/usr/bin/env bash
# Usage: check_port_listening <port>
port=$1
if [ -z "$port" ]; then
    echo "Usage: check_port_listening <port>"
    exit 1
fi

pid=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1)
if [ -n "$pid" ]; then
    echo "PID $pid is listening on port $port."
elif pid=$(lsof -iTCP:"$port" -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2{print $2}'); [ -n "$pid" ]; then
    echo "PID $pid is listening on port $port."
else
    echo "Port $port is NOT listening."
    exit 1
fi
