#!/usr/bin/env bash
# Usage: docker_entrypoint <container>
docker inspect --format='ENTRYPOINT: {{json .Config.Entrypoint}} CMD: {{json .Config.Cmd}}' "$1"
