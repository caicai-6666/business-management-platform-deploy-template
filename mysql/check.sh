#!/bin/sh
# 每次创建独立的 Compose 项目和卷，清理只作用于该次验收。
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
project="mysql-check-$(basename "$work" | tr '[:upper:].' '[:lower:]-')"
MYSQL_ROOT_PASSWORD=$(openssl rand -hex 24)
MYSQL_PASSWORD=$(openssl rand -hex 24)
export MYSQL_PASSWORD MYSQL_ROOT_PASSWORD
export MYSQL_USER=platform MYSQL_DATABASE=platform
compose() { docker compose --env-file /dev/null -p "$project" --profile mysql "$@"; }
cleanup() {
    compose down -v --rmi local --remove-orphans >/dev/null
    rmdir "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
compose up --build --no-recreate -d --wait mysql
compose run --no-deps --rm --build mysql-client env PYTHONPATH=/template python tests/fixtures/mysql_search.py
compose restart mysql
compose up --no-recreate -d --wait mysql
compose run --no-deps --rm mysql-client env PYTHONPATH=/template python tests/fixtures/mysql_search.py --reopen
