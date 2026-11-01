#!/usr/bin/env bash
# Usage: docker_rm_by_network <network-name>
network="$1"
if [ -z "$network" ]; then
    echo "Usage: docker_rm_by_network <network-name>"
    exit 1
fi

docker ps -aq | while read -r id; do
    if docker inspect "$id" --format '{{json .NetworkSettings.Networks}}' | grep -q "$network"; then
        echo "removing $id"
        docker rm -f "$id"
    fi
done
