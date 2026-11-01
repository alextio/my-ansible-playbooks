#!/usr/bin/env bash
# Usage: bws_upsert_secret.sh [-p project-id|name] [-n note] [-b|--bcrypt] [--format alnum|base64|hex] [--input-password] KEY
#
# Creates a secret in Bitwarden Secrets Manager with a randomly generated
# 32-char alphanumeric value. Refuses to overwrite an existing secret, since
# that would rotate it.
#   bws_upsert_secret.sh -p k3s-prod langfuse-encryption-key
#
# --format picks the shape of the generated value (not valid with
# --input-password):
#   alnum   32 chars [A-Za-z0-9] (default)
#   base64  44 chars, `openssl rand -base64 32`: decodes to 32 bytes
#   hex     64 chars, `openssl rand -hex 32`: 32 bytes
#   bws_upsert_secret.sh --format hex -p k3s-prod langfuse-salt
#
# --input-password supplies your own value instead: read from stdin when
# piped, otherwise prompted for (hidden, entered twice). An existing secret
# is then updated in place.
#   pbpaste | bws_upsert_secret.sh --input-password -p k3s-prod GITHUB_TOKEN
#
# -b/--bcrypt stores the bcrypt hash of the value instead of the value itself (needs
# htpasswd), e.g. for ExternalSecrets that inject a password hash into a
# config. The hashed entry gets the note "bcrypt hash" unless -n is given. A
# generated plaintext is kept in Bitwarden as KEY-plaintext so you can log in
# (the note then reads "bcrypt hash of KEY-plaintext"):
#   bws_upsert_secret.sh -b -p k3s-prod adguard-admin-password-hash
#
# The secret's UUID is printed on success: it is what an ExternalSecret's
# remoteRef.key needs.
#
# Without -p, the only project is used, or you pick from a menu (menu needs a
# terminal). bws only accepts the value as an argument, so it is briefly
# visible in the process list while bws runs.
set -euo pipefail

usage() {
    echo "Usage: bws_upsert_secret.sh [-p project-id|name] [-n note] [-b|--bcrypt] [--format alnum|base64|hex] [--input-password] KEY" >&2
    exit 1
}

die() {
    echo "$1" >&2
    exit 1
}

# getopts has no long options: pull them out first and map --bcrypt to -b
generate=1 format="" argv=()
while [ $# -gt 0 ]; do
    case $1 in
        --input-password) generate=0 ;;
        --bcrypt) argv+=(-b) ;;
        --format=*) format=${1#--format=} ;;
        --format) [ $# -ge 2 ] || usage; format=$2; shift ;;
        *) argv+=("$1") ;;
    esac
    shift
done
set -- ${argv[@]+"${argv[@]}"}

case $format in
    "" | alnum | base64 | hex) ;;
    *) die "Unknown --format '$format' (alnum, base64, hex)" ;;
esac
[ -z "$format" ] || [ "$generate" -eq 1 ] || die "--format only applies to generated values"

project="" note="" hash_algo=""
while getopts "p:n:b" opt; do
    case $opt in
        p) project=$OPTARG ;;
        n) note=$OPTARG ;;
        b) hash_algo=bcrypt ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
key=$1

command -v bws >/dev/null || die "bws not found"
[ "$generate" -eq 0 ] || command -v openssl >/dev/null || die "openssl not found"
case $hash_algo in
    bcrypt) command -v htpasswd >/dev/null || die "htpasswd not found (apache2-utils / httpd-tools)" ;;
esac
[ -n "${BWS_ACCESS_TOKEN:-}" ] || die "BWS_ACCESS_TOKEN is not set"

# tsv: ID, Name, Creation Date (after a header row)
projects=$(bws project list -o tsv | tail -n +2)
[ -n "$projects" ] || die "No projects visible to this access token"

if [ -n "$project" ]; then
    project_id=$(awk -F'\t' -v p="$project" '$1 == p || $2 == p { print $1; exit }' <<<"$projects")
    [ -n "$project_id" ] || die "No project matching '$project'"
elif [ "$(wc -l <<<"$projects")" -eq 1 ]; then
    project_id=$(cut -f1 <<<"$projects")
else
    [ -t 0 ] || die "Multiple projects: pass -p when piping the value"
    ids=() names=()
    while IFS=$'\t' read -r id name _; do
        ids+=("$id")
        names+=("$name")
    done <<<"$projects"
    PS3="Project: "
    select name in "${names[@]}"; do
        if [ -n "$name" ]; then
            project_id=${ids[$((REPLY - 1))]}
            break
        fi
    done
    [ -n "${project_id:-}" ] || die "No project selected"
fi

# Sets secret_id to the id of the secret named $1 in the project (empty if none)
find_secret() {
    secret_id=$(bws secret list "$project_id" -o tsv | awk -F'\t' -v k="$1" 'NR > 1 && $2 == k { print $1; exit }')
}

# upsert KEY VALUE NOTE: sets secret_id
upsert() {
    local k=$1 v=$2 n=$3
    local args=(-o none)
    find_secret "$k"
    if [ -n "$secret_id" ]; then
        [ -z "$n" ] || args+=("--note=$n")
        bws secret edit "${args[@]}" "--value=$v" "$secret_id"
        echo "Updated '$k' in project $project_id (id: $secret_id)"
    else
        [ -z "$n" ] || args+=(--note "$n")
        bws secret create "${args[@]}" -- "$k" "$v" "$project_id"
        find_secret "$k"
        echo "Created '$k' in project $project_id (id: $secret_id)"
    fi
}

if [ "$generate" -eq 1 ]; then
    find_secret "$key"
    [ -z "$secret_id" ] || die "'$key' already exists; generating would rotate it. Delete it first, or use --input-password"
    case ${format:-alnum} in
        alnum) value=$(openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-32) ;;
        base64) value=$(openssl rand -base64 32 | tr -d '\n') ;;
        hex) value=$(openssl rand -hex 32) ;;
    esac
elif [ -t 0 ]; then
    read -rsp "Value for $key: " value
    echo >&2
    read -rsp "Confirm: " confirm
    echo >&2
    [ "$value" = "$confirm" ] || die "Values do not match"
else
    value=$(cat)
fi
[ -n "$value" ] || die "Value is empty"

plaintext=$value
keep_plaintext=0
case $hash_algo in
    bcrypt)
        # -i reads the password from stdin so it stays out of the process list
        value=$(printf '%s' "$value" | htpasswd -niBC 10 "" | tr -d ':\n')
        ;;
esac

# Mark hashed entries so they are not mistaken for the plaintext. An
# explicit -n wins.
if [ -n "$hash_algo" ]; then
    [ "$generate" -eq 0 ] || keep_plaintext=1
    if [ -z "$note" ]; then
        note="$hash_algo hash"
        [ "$keep_plaintext" -eq 0 ] || note+=" of $key-plaintext"
    fi
fi

upsert "$key" "$value" "$note"
hash_id=$secret_id
if [ "$keep_plaintext" -eq 1 ]; then
    upsert "$key-plaintext" "$plaintext" "Plaintext for $key"
fi
echo "remoteRef.key: $hash_id"
