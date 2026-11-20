#!/bin/sh
# 供宿主机的服务管理器以前台进程运行，每个 frpc 实例单独启动。
set -eu
if [ "$#" -ne 5 ]; then
    echo 'usage: connect.sh SSH_ALIAS REMOTE_FRPS_PORT LOCAL_CONTROL_PORT FRPC_CONFIG FRPS_ADDRESS' >&2
    exit 2
fi
alias_name=$1
remote_port=$2
local_port=$3
config=$4
address=$5
case "$alias_name" in ''|-*|*[!a-zA-Z0-9_.-]*) exit 2;; esac
case "$address" in ''|-*|*[!a-zA-Z0-9_.-]*) exit 2;; esac
for port in "$remote_port" "$local_port"; do
    case "$port" in ''|*[!0-9]*) exit 2;; esac
    [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 2
done
export FRP_SERVER_ADDR=127.0.0.1 FRP_CONTROL_PORT="$local_port"
frpc verify -c "$config"
state=$(mktemp -d /tmp/platform-frp-ssh.XXXXXXXX)
control=$state/control
pid=
cleanup() {
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || :
        wait "$pid" 2>/dev/null || :
    fi
    ssh -S "$control" -O exit "$alias_name" >/dev/null 2>&1 || :
    rm -rf "$state"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
ssh -fN -M -S "$control" -o BatchMode=yes -o StrictHostKeyChecking=yes \
    -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
    -L "127.0.0.1:$local_port:$address:$remote_port" "$alias_name"
frpc -c "$config" &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
    ssh -S "$control" -O check "$alias_name" >/dev/null 2>&1 || exit 1
    sleep 2
done
wait "$pid"
