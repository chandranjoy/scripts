#!/bin/bash

# ---------------- CONFIG ----------------
EMAIL_TO="mon@domain.com"
EMAIL_FROM="mon@domain.com"
ALERT_DAYS=10
LOG_FILE="/var/log/ssl_expiry_check.log"

WEBSITES=(
  "domain.com"
  "domain.co.in"
)
# ----------------------------------------

echo "----- $(date) SSL Check -----" >> "$LOG_FILE"

ALERT_MSG=""
ALERT_FOUND=0

for SITE in "${WEBSITES[@]}"
do
    EXPIRY_DATE=$(echo | openssl s_client -servername "$SITE" -connect "$SITE:443" 2>/dev/null \
        | openssl x509 -noout -enddate | cut -d= -f2)

    if [ -z "$EXPIRY_DATE" ]; then
        ALERT_MSG+="❌ $SITE : Unable to fetch certificate\n"
        ALERT_FOUND=1
        continue
    fi

    EXPIRY_SECONDS=$(date -d "$EXPIRY_DATE" +%s)
    NOW_SECONDS=$(date +%s)

    DAYS_LEFT=$(( (EXPIRY_SECONDS - NOW_SECONDS) / 86400 ))

    echo "$SITE expires in $DAYS_LEFT days" >> "$LOG_FILE"

    if [ "$DAYS_LEFT" -le "$ALERT_DAYS" ]; then
        ALERT_MSG+="⚠️ $SITE SSL expires in $DAYS_LEFT days (Expiry: $EXPIRY_DATE)\n"
        ALERT_FOUND=1
    fi
done

# Send mail only if alert exists
if [ "$ALERT_FOUND" -eq 1 ]; then
    echo -e "$ALERT_MSG" | mail -r "$EMAIL_FROM" -s "Important: SSL Expiry Alert" "$EMAIL_TO"
fi
