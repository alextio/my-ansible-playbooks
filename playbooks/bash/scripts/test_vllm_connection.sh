#!/usr/bin/env bash
# Test connectivity to a vLLM server running on a remote host.
# Usage: test_vllm_connection <ssh-alias> [port] [token]
alias=$1
port=${2:-8000}
token=${3:-token-local07302024}

host=$(ssh -G "$alias" | awk '$1 == "hostname" { print $2 }')
base_url="http://$host:$port"

echo "🔍 Querying $alias ($host) on port $port..."

models_json=$(curl -s -H "Authorization: Bearer $token" "$base_url/v1/models")

model_name=$(echo "$models_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['data'][0]['id']) if 'data' in data and data['data'] else print('')
" 2>/dev/null)

if [ -z "$model_name" ]; then
    echo "❌ Error: Could not find an active model or server is unreachable."
    echo "Response received: $models_json"
    exit 1
fi

echo "✅ Found model: $model_name"
echo "🚀 Sending test request with token: ${token:0:5}***"

curl "$base_url/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "{
        \"model\": \"$model_name\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Hello.\"}],
        \"max_tokens\": 10
    }"
