#!/bin/bash

# Check for required arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <appname> <domain> <local-port>"
    exit 1
fi

# Check for Cloudflare cert
CERT_PATH="${HOME}/.cloudflared/cert.pem"
if [ ! -f "$CERT_PATH" ]; then
    echo "❌ Cloudflare origin certificate not found!"
    echo "Run first: cloudflared tunnel login"
    exit 1
fi

APPNAME=$1
DOMAIN=$2
PORT=$3
TUNNEL_NAME="${APPNAME}-tunnel"
CONFIG_FILE="cloudflared-${APPNAME}.yml"

# Check if tunnel already exists
echo "Checking if tunnel ${TUNNEL_NAME} already exists..."
TUNNEL_ID=$(cloudflared tunnel list | grep "${TUNNEL_NAME}" | awk '{print $1}')

if [ -z "${TUNNEL_ID}" ]; then
    # Create new Cloudflare Tunnel if it doesn't exist
    echo "Creating tunnel: ${TUNNEL_NAME}..."
    CREATE_OUTPUT=$(cloudflared tunnel create ${TUNNEL_NAME})
    TUNNEL_ID=$(echo "${CREATE_OUTPUT}" | sed -n 's/.*Created tunnel .* with id \([^ ]*\).*/\1/p')

    if [ -z "${TUNNEL_ID}" ]; then
        echo "❌ Failed to create tunnel"
        exit 1
    fi
    echo "✅ Tunnel created with ID: ${TUNNEL_ID}"
else
    echo "✅ Tunnel ${TUNNEL_NAME} already exists with ID: ${TUNNEL_ID}"
fi

# Create configuration file with certificate path
echo "Generating config file: ${CONFIG_FILE}"
cat << EOF > ${CONFIG_FILE}
tunnel: ${TUNNEL_ID}
credentials-file: ${HOME}/.cloudflared/${TUNNEL_ID}.json
origincert: ${CERT_PATH}

ingress:
  - hostname: ${APPNAME}.${DOMAIN}
    service: http://localhost:${PORT}
  - service: http_status:404
EOF

# Check if DNS record already exists
echo "Checking if DNS record for ${APPNAME}.${DOMAIN} already exists..."
DNS_CHECK=$(cloudflared tunnel route dns ${TUNNEL_NAME} ${APPNAME}.${DOMAIN} 2>&1)
if [[ $DNS_CHECK == *"already exists"* ]]; then
    echo "✅ DNS record for ${APPNAME}.${DOMAIN} already exists"
else
    # Create DNS record
    echo "Creating DNS route: ${APPNAME}.${DOMAIN}..."
    cloudflared tunnel route dns ${TUNNEL_NAME} ${APPNAME}.${DOMAIN}
    echo "✅ DNS record created"
fi

# Start the tunnel in background with logging
echo "🚀 Starting tunnel ${TUNNEL_NAME} in background..."
echo "🔗 Your service is available at: https://${APPNAME}.${DOMAIN}"
echo "📝 Logs: ${APPNAME}-cloudflared.log"
echo "💾 PID: ${APPNAME}-cloudflared.pid"

# Check if tunnel is already running
if [ -f "${APPNAME}-cloudflared.pid" ] && ps -p $(cat ${APPNAME}-cloudflared.pid) > /dev/null; then
    echo "⚠️ Tunnel is already running with PID: $(cat ${APPNAME}-cloudflared.pid)"
    echo "Stopping existing tunnel..."
    kill $(cat ${APPNAME}-cloudflared.pid)
    rm ${APPNAME}-cloudflared.pid
    sleep 2
fi

# Run tunnel in background with logging
cloudflared tunnel --config ${CONFIG_FILE} run ${TUNNEL_NAME} > ${APPNAME}-cloudflared.log 2>&1 &

# Save PID for management
echo $! > ${APPNAME}-cloudflared.pid

# Verify process is running
sleep 1
if ps -p $(cat ${APPNAME}-cloudflared.pid) > /dev/null; then
    echo "✅ Tunnel successfully started (PID: $(cat ${APPNAME}-cloudflared.pid))"
else
    echo "❌ Failed to start tunnel - check logs"
    rm ${APPNAME}-cloudflared.pid
    exit 1
fi
