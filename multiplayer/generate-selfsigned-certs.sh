#!/bin/bash

# Script to generate self-signed certificates for local development
# Usage: ./generate-selfsigned-certs.sh [additional-domain]

set -e

CERT_DIR="./ssl/selfsigned"
DOMAIN="bluesim.blueos.cloud"
WILDCARD_DOMAIN="*.bluesim.blueos.cloud"
ADDITIONAL_DOMAIN="${1:-}"

echo "Creating certificate directory..."
mkdir -p "$CERT_DIR"

if [ -n "$ADDITIONAL_DOMAIN" ]; then
    echo "Generating self-signed certificate for $DOMAIN, $WILDCARD_DOMAIN, and $ADDITIONAL_DOMAIN..."
else
    echo "Generating self-signed certificate for $DOMAIN and $WILDCARD_DOMAIN..."
fi
echo "This certificate will be valid for 365 days."

# Generate private key
openssl genrsa -out "$CERT_DIR/privkey.pem" 4096

# Create OpenSSL configuration file for SAN (Subject Alternative Names)
cat > "$CERT_DIR/openssl.cnf" <<EOF
[req]
default_bits = 4096
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = BlueOS Development
OU = Simulator
CN = $DOMAIN

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[v3_ca]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = $WILDCARD_DOMAIN
DNS.3 = sim.bluesim.blueos.cloud
DNS.4 = player1.bluesim.blueos.cloud
DNS.5 = player2.bluesim.blueos.cloud
DNS.6 = player3.bluesim.blueos.cloud
DNS.7 = player4.bluesim.blueos.cloud
DNS.8 = localhost
DNS.9 = *.nip.io
IP.1 = 127.0.0.1
EOF

# Add additional domain if provided
if [ -n "$ADDITIONAL_DOMAIN" ]; then
    # Extract base domain and create variations
    BASE_DOMAIN="$ADDITIONAL_DOMAIN"
    echo "DNS.10 = $BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
    echo "DNS.11 = sim.$BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
    echo "DNS.12 = player1.$BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
    echo "DNS.13 = player2.$BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
    echo "DNS.14 = player3.$BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
    echo "DNS.15 = player4.$BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
    echo "DNS.16 = *.$BASE_DOMAIN" >> "$CERT_DIR/openssl.cnf"
fi

# Generate certificate signing request (CSR)
openssl req -new -key "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/cert.csr" \
    -config "$CERT_DIR/openssl.cnf"

# Generate self-signed certificate
openssl x509 -req -days 365 \
    -in "$CERT_DIR/cert.csr" \
    -signkey "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -extensions v3_ca \
    -extfile "$CERT_DIR/openssl.cnf"

# Clean up CSR
rm "$CERT_DIR/cert.csr"

# Also create copies with the alternative naming convention used in nginx.conf
cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/nginx-selfsigned.crt"
cp "$CERT_DIR/privkey.pem" "$CERT_DIR/nginx-selfsigned.key"

echo ""
echo "✅ Self-signed certificates generated successfully!"
echo ""
echo "Certificate files created:"
echo "  - $CERT_DIR/fullchain.pem"
echo "  - $CERT_DIR/privkey.pem"
echo "  - $CERT_DIR/nginx-selfsigned.crt"
echo "  - $CERT_DIR/nginx-selfsigned.key"
echo ""
echo "⚠️  IMPORTANT: Self-signed certificates will show security warnings in browsers."
echo "   You'll need to accept the security exception or add the certificate to your"
echo "   trusted root certificates."
echo ""
echo "To view certificate details:"
echo "  openssl x509 -in $CERT_DIR/fullchain.pem -text -noout"
echo ""
