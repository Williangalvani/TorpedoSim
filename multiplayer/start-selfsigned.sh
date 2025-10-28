#!/bin/bash

# Startup script for local development with self-signed certificates
# Usage: ./start-selfsigned.sh <baseurl>

set -e

# Check for baseurl argument
if [ -z "$1" ]; then
    echo "Usage: $0 <baseurl>"
    echo "Example: $0 https://sim.bluesim.blueos.cloud"
    exit 1
fi

BASEURL="$1"
CERT_DIR="./ssl/selfsigned"

# Extract domain from URL for certificate generation
CERT_DOMAIN=$(echo "$BASEURL" | sed -E 's|https?://||' | sed -E 's|/.*||' | sed -E 's/^(sim|player[0-9])\.//') 

echo "🚀 Starting BlueOS Simulator with self-signed certificates..."
echo "   Base URL: $BASEURL"
echo "   Certificate domain: $CERT_DOMAIN"
echo ""

# Check if certificates exist and are valid for the domain
REGEN_CERT=false
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    REGEN_CERT=true
    echo "📜 Self-signed certificates not found."
elif ! openssl x509 -in "$CERT_DIR/fullchain.pem" -text -noout | grep -q "$CERT_DOMAIN" 2>/dev/null; then
    REGEN_CERT=true
    echo "📜 Certificate doesn't cover domain $CERT_DOMAIN."
fi

if [ "$REGEN_CERT" = true ]; then
    echo "🔧 Generating new certificate..."
    ./generate-selfsigned-certs.sh "$CERT_DOMAIN"
    echo ""
fi

# Create ssl directory and link self-signed certs to expected location
mkdir -p ssl
ln -sf selfsigned/fullchain.pem ssl/fullchain.pem
ln -sf selfsigned/privkey.pem ssl/privkey.pem

# Create player directories
echo "📁 Setting up player directories..."
mkdir -p blueos1 blueos2 blueos3 blueos4

# Copy configuration files to individual player folders
cp eeprom.bin bag-of-holding blueos1/
cp eeprom.bin bag-of-holding blueos2/
cp eeprom.bin bag-of-holding blueos3/
cp eeprom.bin bag-of-holding blueos4/

# Configure each player with the appropriate URL
echo "⚙️  Configuring player URLs..."
sed -i.bak "s,\$IFRAME_URL,$BASEURL?player=1," blueos1/bag-of-holding
sed -i.bak "s,\$IFRAME_URL,$BASEURL?player=2," blueos2/bag-of-holding
sed -i.bak "s,\$IFRAME_URL,$BASEURL?player=3," blueos3/bag-of-holding
sed -i.bak "s,\$IFRAME_URL,$BASEURL?player=4," blueos4/bag-of-holding

# Remove backup files
rm -f blueos*/bag-of-holding.bak

echo ""
echo "🐳 Starting Docker Compose with self-signed certificates..."
# Stop any running containers first
docker compose down 2>/dev/null || true

# Start docker compose
docker compose up -d

echo ""
echo "✅ Simulator started successfully!"
echo ""
echo "⚠️  IMPORTANT: You're using self-signed certificates"
echo "   Your browser will show a security warning. You need to:"
echo "   1. Click 'Advanced' or 'Show Details'"
echo "   2. Click 'Proceed to site' or 'Accept Risk'"
echo ""
echo "🌐 Access: $BASEURL"
echo ""
echo "📊 To view logs: docker compose logs -f"
echo "🛑 To stop: docker compose down"
echo ""
