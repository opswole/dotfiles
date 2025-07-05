#!/bin/bash

# Load secrets
ENV_FILE="/home/opswole/bin/.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "Missing .env file: $ENV_FILE"
  exit 1
fi

# Domain records to update
RECORDS=("christopherfagg.me" "api.christopherfagg.me")

# Get current local/public IP
LOCAL_IP=$(curl -s https://icanhazip.com)

# Get the current DNS IP for christopherfagg.me
DNS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=christopherfagg.me&type=A" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

DNS_IP=$(echo "$DNS_RESPONSE" | jq -r '.result[0].content')

# Compare IPs
if [ "$LOCAL_IP" == "$DNS_IP" ]; then
  echo "$(date) - IPs match ($LOCAL_IP). No update needed."
  exit 0
else
  echo "$(date) - IPs differ. Updating Cloudflare DNS records..."
fi

# Loop through and update each A record
for RECORD_NAME in "${RECORDS[@]}"; do
  RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$RECORD_NAME&type=A" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

  RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id')

  if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" == "null" ]; then
    echo "Could not find record ID for $RECORD_NAME. Skipping."
    continue
  fi

  UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$LOCAL_IP\",\"ttl\":1,\"proxied\":false}")

  if echo "$UPDATE_RESPONSE" | grep -q '"success":true'; then
    echo "Successfully updated $RECORD_NAME to $LOCAL_IP"
  else
    echo "Failed to update $RECORD_NAME"
    echo "$UPDATE_RESPONSE"
  fi
done
