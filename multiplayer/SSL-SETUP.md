# SSL Certificate Setup Guide

This directory supports two SSL certificate options for the BlueOS Simulator:

## Option 1: Let's Encrypt Certificates (Production)

**Use this for:** Production deployments with public domain names

### Setup:
```bash
# Generate Let's Encrypt certificates (run certbot first)
docker compose --profile certs up certbot

# Start the simulator with Let's Encrypt certificates
./start.sh https://sim.bluesim.blueos.cloud
```

### Files used:
- `docker-compose.yml` - Main compose file with certbot service
- `nginx.conf` - Nginx configuration for Let's Encrypt
- `start.sh` - Startup script

### Requirements:
- Public domain names pointing to your server
- Ports 80 and 443 open to the internet
- Valid DNS records for all subdomains

---

## Option 2: Self-Signed Certificates (Development/Local)

**Use this for:** Local development, testing, or internal networks where Let's Encrypt is not suitable

### Quick Start:
```bash
# One command to generate certificates and start the simulator
./start-selfsigned.sh https://sim.bluesim.blueos.cloud
```

The script will automatically:
1. Generate self-signed certificates (if they don't exist)
2. Set up player directories
3. Start Docker Compose with the self-signed configuration

### Manual Certificate Generation:
If you want to generate certificates separately:
```bash
./generate-selfsigned-certs.sh
```

### Files used:
- `docker-compose.selfsigned.yml` - Compose file for self-signed setup
- `nginx.selfsigned.conf` - Nginx configuration for self-signed certificates
- `start-selfsigned.sh` - Startup script with automatic certificate generation
- `generate-selfsigned-certs.sh` - Certificate generation script

### Certificate Details:
- **Validity:** 365 days
- **Key Size:** 4096-bit RSA
- **Domains Covered:**
  - `bluesim.blueos.cloud`
  - `*.bluesim.blueos.cloud` (wildcard)
  - `sim.bluesim.blueos.cloud`
  - `player1.bluesim.blueos.cloud`
  - `player2.bluesim.blueos.cloud`
  - `player3.bluesim.blueos.cloud`
  - `player4.bluesim.blueos.cloud`
  - `localhost`

### Browser Security Warnings:

⚠️ **Important:** Self-signed certificates will trigger browser security warnings. You'll need to:

1. Visit each URL in your browser
2. Click "Advanced" or "Show Details"
3. Click "Proceed to site" or "Accept Risk"
4. Repeat for all domains you need to access

### Trusting Self-Signed Certificates (Optional):

To avoid browser warnings, you can add the certificate to your system's trust store:

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain \
  ./ssl/selfsigned/fullchain.pem
```

**Linux:**
```bash
sudo cp ./ssl/selfsigned/fullchain.pem /usr/local/share/ca-certificates/bluesim.crt
sudo update-ca-certificates
```

**Windows:**
Import `ssl/selfsigned/fullchain.pem` into "Trusted Root Certification Authorities" using certmgr.msc

### Managing the Self-Signed Setup:

**View logs:**
```bash
docker compose -f docker-compose.selfsigned.yml logs -f
```

**Stop services:**
```bash
docker compose -f docker-compose.selfsigned.yml down
```

**Restart services:**
```bash
docker compose -f docker-compose.selfsigned.yml restart
```

**Regenerate certificates:**
```bash
rm -rf ./ssl/selfsigned
./generate-selfsigned-certs.sh
docker compose -f docker-compose.selfsigned.yml restart nginx
```

---

## Switching Between Configurations

The two setups are completely independent and don't interfere with each other:

**From Let's Encrypt to Self-Signed:**
```bash
docker compose down
./start-selfsigned.sh https://sim.bluesim.blueos.cloud
```

**From Self-Signed to Let's Encrypt:**
```bash
docker compose -f docker-compose.selfsigned.yml down
./start.sh https://sim.bluesim.blueos.cloud
```

---

## Troubleshooting

### Certificate errors on startup:
```bash
# Check if certificates exist
ls -la ./ssl/selfsigned/

# Regenerate if needed
./generate-selfsigned-certs.sh
```

### nginx fails to start:
```bash
# Check nginx configuration
docker compose -f docker-compose.selfsigned.yml exec nginx nginx -t

# View nginx logs
docker compose -f docker-compose.selfsigned.yml logs nginx
```

### Browser still shows warnings after trusting certificate:
- Restart your browser completely
- Clear browser cache and SSL state
- Verify the certificate is in the system trust store
- On macOS, verify using: `security find-certificate -c "bluesim.blueos.cloud"`

---

## Certificate Files Location

**Let's Encrypt:**
- Managed by Docker volume: `letsencrypt-certs`
- Mounted at: `/etc/letsencrypt` in containers

**Self-Signed:**
- Directory: `./ssl/selfsigned/`
- Files:
  - `fullchain.pem` - Certificate
  - `privkey.pem` - Private key
  - `nginx-selfsigned.crt` - Alternative certificate name
  - `nginx-selfsigned.key` - Alternative key name
  - `openssl.cnf` - OpenSSL configuration used during generation

---

## Security Notes

⚠️ **Self-Signed Certificates:**
- Should **NOT** be used in production environments
- Provide encryption but **NO identity verification**
- Users must manually accept certificate warnings
- Not recognized by browsers or systems by default

✅ **Let's Encrypt Certificates:**
- Free and trusted by all major browsers
- Automatic renewal support
- Proper identity verification
- Recommended for production use

