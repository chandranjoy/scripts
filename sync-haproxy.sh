#!/bin/bash
# sync-haproxy.sh
# Script to sync HAProxy certs and config from lb01 to lb02 using SSH on SSH port 22
# Date
DT_NOW=$(date "+%Y-%m-%d %H:%M:%S")

# Log file
LOG_FILE="/var/log/sync-haproxy.log"

# Remote server details
REMOTE_USER="root"
REMOTE_HOST="lb02"
REMOTE_PORT=22

# Paths
CERTS_DIR="/etc/haproxy/certs"
CONFIG_FILE="/etc/haproxy/haproxy.cfg"

echo $DT_NOW
echo "=== Syncing HAProxy configuration $REMOTE_HOST ==="

# Sync certs directory
rsync -avz -e "ssh -p $REMOTE_PORT" "$CERTS_DIR/" "$REMOTE_USER@$REMOTE_HOST:$CERTS_DIR/"

# Sync haproxy.cfg
rsync -avz -e "ssh -p $REMOTE_PORT" "$CONFIG_FILE" "$REMOTE_USER@$REMOTE_HOST:$CONFIG_FILE"

# Optionally reload HAProxy on lb02 after sync
ssh -p $REMOTE_PORT "$REMOTE_USER@$REMOTE_HOST" "systemctl reload haproxy"

echo "==== Syncing HAProxy configuration completed ====="
