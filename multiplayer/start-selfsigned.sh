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

echo "🚀 Starting BlueOS Simulator with self-signed certificates..."
echo ""

# Check if certificates exist
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    echo "📜 Self-signed certificates not found. Generating them now..."
    ./generate-selfsigned-certs.sh
    echo ""
fi

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
docker compose -f docker-compose.selfsigned.yml up -d

echo ""
echo "✅ Simulator started successfully!"
echo ""
echo "⚠️  IMPORTANT: You're using self-signed certificates"
echo "   Your browser will show a security warning. You need to:"
echo "   1. Click 'Advanced' or 'Show Details'"
echo "   2. Click 'Proceed to site' or 'Accept Risk'"
echo "   3. Do this for each domain:"
echo "      - $BASEURL"
echo "      - https://player1.bluesim.blueos.cloud"
echo "      - https://player2.bluesim.blueos.cloud"
echo ""
echo "📊 To view logs: docker compose -f docker-compose.selfsigned.yml logs -f"
echo "🛑 To stop: docker compose -f docker-compose.selfsigned.yml down"
echo ""

