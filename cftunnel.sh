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

# Create new Cloudflare Tunnel
echo "Creating tunnel: ${TUNNEL_NAME}..."
CREATE_OUTPUT=$(cloudflared tunnel create ${TUNNEL_NAME})
TUNNEL_ID=$(echo "${CREATE_OUTPUT}" | sed -n 's/.*Created tunnel .* with id \([^ ]*\).*/\1/p')

if [ -z "${TUNNEL_ID}" ]; then
    echo "❌ Failed to create tunnel"
    exit 1
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

# Create DNS record
echo "Creating DNS route: ${APPNAME}.${DOMAIN}..."
cloudflared tunnel route dns ${TUNNEL_NAME} ${APPNAME}.${DOMAIN}

# Start the tunnel in background with logging
echo "🚀 Starting tunnel ${TUNNEL_NAME} in background..."
echo "🔗 Your service is available at: https://${APPNAME}.${DOMAIN}"
echo "📝 Logs: ${APPNAME}-cloudflared.log"
echo "💾 PID: ${APPNAME}-cloudflared.pid"

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
