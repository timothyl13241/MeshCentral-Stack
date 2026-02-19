# MeshCentral Docker Stack

A secure, production-ready Docker Compose stack for [MeshCentral](https://meshcentral.com/), featuring automatic HTTPS with Caddy Cloudflare DNS challenge, secure environment variable management, and optional CrowdSec integration.

### Service Roles

- **MeshCentral**: Remote device management server for monitoring and controlling devices remotely
- **MongoDB**: Persistent database with required authentication and optional encryption-at-rest capability
- **Caddy**: Modern reverse proxy with automatic HTTPS via Let's Encrypt using Cloudflare DNS challenge
- **CrowdSec**: Optional automated intrusion prevention system with community-driven threat intelligence
- **Cloudflared**: Optional Cloudflare Tunnel integration for enhanced security and zero-trust access

## 🔒 Security Features

- **Network Isolation**: Separate frontend and internal backend networks
- **MongoDB Authentication**: Required database authentication with dedicated user accounts
- **Encrypted Storage Ready**: MongoDB configured for encryption-at-rest capability
- **TLS Termination**: Automatic HTTPS certificates via Let's Encrypt with Cloudflare DNS challenge
- **Security Headers**: HSTS, CSP, X-Frame-Options, and more
- **Real IP Preservation**: Proper forwarding of CF-Connecting-IP for accurate logging and rate limiting
- **Password Policies**: Enforced strong password requirements
- **Rate Limiting**: Built-in login rate limiting and invalid login tracking
- **Secrets Management**: Secure environment-based configuration with no hardcoded credentials
- **CrowdSec Integration**: Automated threat intelligence and IP reputation-based blocking (Optional)

## 📋 Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 2.x or later
- A domain name pointing to your server (or using Cloudflare for DNS)
- Cloudflare API Token with DNS edit permissions (for automatic HTTPS)
- (Optional) Cloudflare account for Tunnel integration

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/timothyl13241/MeshCentral-Stack.git
cd MeshCentral-Stack
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with your settings
nano .env
```

**Required Configuration:**

- `MESHCENTRAL_HOSTNAME`: Your domain name (e.g., mesh.example.com)
- `ACME_EMAIL`: Email for Let's Encrypt notifications
- `CLOUDFLARE_API_TOKEN`: Cloudflare API token with DNS edit permissions (for automatic HTTPS)
- `MONGO_ROOT_PASSWORD`: Strong password for MongoDB root user
- `MESHCENTRAL_DB_PASSWORD`: Strong password for MeshCentral database user

**Generate Secure Passwords:**

```bash
# Generate a strong password
openssl rand -base64 32
```

**Important:** After configuring your `.env` file, you must render the configuration files before starting the stack (see next step).

### 3. Render Configuration Files

The MeshCentral configuration uses a template-based approach with environment variable substitution. You need to render the configuration file before starting the stack.

```bash
# Render the config.json from template
./render-config.sh
```

**MeshCentral Configuration (render-config.sh):**
- Loads variables from your `.env` file
- Uses `envsubst` to substitute all `${VARNAME}` placeholders in `meshcentral-data/config.json.template`
- Generates `meshcentral-data/config.json` with actual values
- Validates the generated JSON (if `jq` is installed)

**Caddyfile Configuration:**
- Caddy automatically substitutes environment variables at runtime using `{$VARNAME}` syntax
- The Caddyfile is directly mounted from `caddy/Caddyfile` - no rendering needed
- Environment variables like `MESHCENTRAL_HOSTNAME`, `ACME_EMAIL`, and `CLOUDFLARE_API_TOKEN` are passed via docker-compose.yml

**Important:** You must run `./render-config.sh` whenever you change environment variables in `.env`.

### 4. Update Configuration (Optional)

The MeshCentral template file contains base configuration with environment variable placeholders:
- `meshcentral-data/config.json.template` - MeshCentral configuration

The Caddyfile uses Caddy's native environment variable substitution:
- `caddy/Caddyfile` - Caddy reverse proxy configuration (uses `{$VARNAME}` syntax)

**Note:** If using CrowdSec, the init container will automatically update the rendered config.json with the correct API key, so no manual configuration is needed.

For advanced customization, you can manually edit the files before starting:

```bash
# Edit the MeshCentral template
nano meshcentral-data/config.json.template

# Edit the Caddyfile directly
nano caddy/Caddyfile

# Re-render MeshCentral configuration
./render-config.sh
```

### 5. Start the Stack

```bash
# Start basic stack (MeshCentral, MongoDB, Caddy)
docker-compose up -d

# Start with CrowdSec protection
docker-compose --profile crowdsec up -d

# Start with Cloudflare Tunnel
docker-compose --profile cloudflare up -d

# Or combine both CrowdSec and Cloudflare
docker-compose --profile crowdsec --profile cloudflare up -d
```

### 6. Verify Installation

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f meshcentral

# Test the web interface
curl -I https://your-domain.com
```

### 7. Access MeshCentral

Open your browser and navigate to:
```
https://your-domain.com
```

Create your first administrator account through the web interface.

## 🌐 Caddy Cloudflare DNS Challenge Setup

This stack uses Caddy with the Cloudflare DNS challenge for automatic HTTPS certificate issuance. This method is particularly useful when:
- Your server is behind a firewall or NAT
- You want to issue wildcard certificates
- HTTP-01 challenge isn't feasible for your setup

### Prerequisites

1. A Cloudflare account with your domain added
2. A Cloudflare API Token with DNS edit permissions

### Creating a Cloudflare API Token

1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **My Profile** → **API Tokens**
3. Click **Create Token**
4. Use the **Edit zone DNS** template or create a custom token with these permissions:
   - **Zone** → **DNS** → **Edit**
   - **Zone** → **Zone** → **Read**
5. Set the **Zone Resources** to include your domain
6. Click **Continue to summary** → **Create Token**
7. Copy the generated token immediately (it won't be shown again)

### Configuring the API Token

Add the token to your `.env` file:

```bash
CLOUDFLARE_API_TOKEN=your_cloudflare_dns_api_token_here
```

### How It Works

When Caddy requests a certificate from Let's Encrypt:

1. Let's Encrypt issues a DNS challenge
2. Caddy uses your `CLOUDFLARE_API_TOKEN` to create a TXT record in your Cloudflare DNS
3. Let's Encrypt verifies the TXT record
4. Certificate is issued and automatically installed
5. Caddy handles automatic renewal (typically every 60 days)

The Cloudflare DNS challenge is configured in the Caddyfile (`caddy/Caddyfile`). The hostname and other variables are automatically substituted at runtime by Caddy using environment variables:

```
# In the Caddyfile:
{$MESHCENTRAL_HOSTNAME} {
  tls {
    protocols tls1.2 tls1.3
    dns cloudflare {$CLOUDFLARE_API_TOKEN}
  }
  # ... rest of configuration
}

# At runtime, Caddy automatically substitutes (e.g., if MESHCENTRAL_HOSTNAME=mesh.example.com):
mesh.example.com {
  tls {
    protocols tls1.2 tls1.3
    dns cloudflare <your_actual_token>
  }
  # ... rest of configuration
}
```

Note: Caddy uses `{$VARNAME}` syntax for environment variable substitution at runtime.

### Verification

After starting the stack, verify certificate issuance:

```bash
# Check Caddy logs for certificate issuance
docker-compose logs caddy | grep -i "certificate"

# Verify HTTPS is working
curl -I https://your-domain.com

# Check certificate details
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null | openssl x509 -noout -text
```

### Troubleshooting

If certificate issuance fails:

```bash
# Check for API token errors
docker-compose logs caddy | grep -i "cloudflare"

# Verify API token has correct permissions
# - Token must have Zone:DNS:Edit and Zone:Zone:Read permissions
# - Token must be scoped to the correct zone

# Test DNS propagation
dig TXT _acme-challenge.your-domain.com

# Force certificate renewal
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## 🔧 Configuration Details

### Docker Compose Services

#### MeshCentral
- **Image**: `ghcr.io/ylianst/meshcentral:latest`
- **Port**: 4430 (internal, proxied by Caddy)
- **Volumes**: 
  - `meshcentral-data`: Configuration and database
  - `meshcentral-files`: Uploaded files
  - `meshcentral-backup`: Automated backups
  - `meshcentral-web`: Web assets

#### MongoDB
- **Image**: `mongo:7`
- **Port**: 27017 (internal only)
- **Authentication**: Enabled by default
- **Encryption**: Can be enabled with keyfile configuration
- **Volumes**: 
  - `mongodb-data`: Database files
  - `mongodb-config`: MongoDB configuration

#### Caddy
- **Image**: `caddy:2-alpine`
- **Ports**: 
  - 80 (HTTP, redirects to HTTPS)
  - 443 (HTTPS)
  - 2019 (Admin API, internal)
- **Features**:
  - Automatic HTTPS with Let's Encrypt using Cloudflare DNS challenge
  - Supports wildcard certificates and servers behind NAT/firewalls
  - WebSocket support for MeshCentral real-time connections
  - CF-Connecting-IP forwarding for CrowdSec and accurate client IP logging
  - Modern security headers (HSTS, CSP, X-Frame-Options)
  - Response compression (gzip, zstd)
  - JSON-formatted access logs with rotation

#### Cloudflared (Optional)
- **Image**: `cloudflare/cloudflared:latest`
- **Profile**: `cloudflare` (must be explicitly enabled)
- **Purpose**: Secure tunneling through Cloudflare network

#### CrowdSec (Optional)
- **Image**: `crowdsecurity/crowdsec:latest`
- **Profile**: `crowdsec` (must be explicitly enabled)
- **Port**: 8080 (LAPI, internal only)
- **Features**:
  - Automated bouncer key generation for MeshCentral
  - Community-driven threat intelligence
  - Real-time IP reputation blocking
  - Log analysis from Caddy
- **Volumes**:
  - `crowdsec-config`: CrowdSec configuration
  - `crowdsec-data`: Threat intelligence database
  - `caddy-data`: Mounted read-only for log analysis

### Network Architecture

```
Internet
    ↓
[Cloudflared (optional)]
    ↓
[Caddy Reverse Proxy] ← meshcentral-frontend (bridge)
    ↓                      ↓ (logs)
[MeshCentral] ←────────→ [CrowdSec (optional)] ← meshcentral-backend (internal)
    ↓
[MongoDB]
```

### Environment Variables

This stack uses secure environment-based configuration to avoid hardcoded credentials. All sensitive values are stored in the `.env` file, which should never be committed to version control.

**Security Best Practices:**
- Always use strong, randomly generated passwords
- Keep the `.env` file secure with `chmod 600 .env`
- Never commit `.env` to Git (it's in `.gitignore`)
- Use different passwords for each service
- Regularly rotate credentials

See `.env.example` for all available configuration options.

### Configuration Rendering Workflow

This stack uses a **host-driven, template-based approach** with environment variable substitution for MeshCentral configuration. Caddy uses native runtime environment variable substitution.

#### MeshCentral Configuration

1. **Template File**: `meshcentral-data/config.json.template` contains the base configuration with `${VARNAME}` placeholders
2. **Environment Variables**: All variables are defined in your `.env` file
3. **Rendering Script**: `render-config.sh` uses `envsubst` to substitute placeholders with actual values
4. **Rendered Config**: `meshcentral-data/config.json` is generated with real values (excluded from git)
5. **Docker Mount**: Only the rendered `config.json` is bind-mounted into the container (read-only)

#### Caddyfile Configuration

1. **Caddyfile**: `caddy/Caddyfile` contains the configuration with `{$VARNAME}` placeholders for Caddy's native substitution
2. **Environment Variables**: Variables are defined in your `.env` file and passed via docker-compose.yml
3. **Runtime Substitution**: Caddy automatically substitutes environment variables at runtime
4. **Docker Mount**: The Caddyfile is directly bind-mounted into the container (read-only)

**Workflow:**

```bash
# 1. Configure environment variables
cp .env.example .env
nano .env

# 2. Render MeshCentral configuration
./render-config.sh

# 3. Start the stack (Caddy will automatically use environment variables)
docker-compose up -d
```

**Important Notes:**
- Always run `./render-config.sh` before starting the stack for the first time
- Re-run the script whenever you change environment variables in `.env`
- The template file (`config.json.template`) is tracked in git
- The rendered file (`config.json`) is excluded from git and contains your actual values
- The MeshCentral rendering script validates JSON output if `jq` is installed
- The Caddyfile uses Caddy's native `{$VARNAME}` syntax for runtime substitution - no rendering needed

**Template Variables:**

All environment variables in `.env` can be used:
- In MeshCentral template with `${VARNAME}` syntax (rendered by envsubst)
- In Caddyfile with `{$VARNAME}` syntax (substituted by Caddy at runtime)

Examples:
- `${MESHCENTRAL_HOSTNAME}` or `{$MESHCENTRAL_HOSTNAME}` - Your domain name
- `${MONGO_DATABASE}` - MongoDB database name
- `${MESHCENTRAL_DB_USER}` - Database user
- `${MESHCENTRAL_DB_PASSWORD}` - Database password
- `${CROWDSEC_LAPI_URL:-http://crowdsec:8080}` - CrowdSec URL (with default value)

**Customization:**

To customize the configurations:

```bash
# Edit the MeshCentral template
nano meshcentral-data/config.json.template

# Edit the Caddyfile directly
nano caddy/Caddyfile

# Re-render MeshCentral configuration
./render-config.sh

# Restart the stack to apply changes
docker-compose restart
```

## 🛡️ Security Best Practices

### 1. Strong Passwords
```bash
# Generate strong passwords for all services
openssl rand -base64 32
```

### 2. Enable MongoDB Encryption at Rest

To enable MongoDB encryption at rest:

```bash
# Generate encryption keyfile
openssl rand -base64 96 > mongodb-keyfile
chmod 400 mongodb-keyfile
chown 999:999 mongodb-keyfile  # MongoDB user in Docker
```

Uncomment the encryption options in `docker-compose.yml`:
```yaml
command: 
  - --auth
  - --enableEncryption
  - --encryptionKeyFile=/etc/mongodb-keyfile
```

Add the keyfile volume mount:
```yaml
volumes:
  - ./mongodb-keyfile:/etc/mongodb-keyfile:ro
```

### 3. File Permissions

```bash
# Secure your environment file
chmod 600 .env

# Secure sensitive directories
chmod 700 meshcentral-data/ mongodb-data/
```

### 4. Firewall Configuration

Only expose necessary ports:

```bash
# Example UFW rules
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 5. Regular Updates

```bash
# Update Docker images
docker-compose pull

# Restart with new images
docker-compose up -d
```

### 6. Backup Strategy

```bash
# Backup MongoDB
docker-compose exec mongodb mongodump --authenticationDatabase admin \
  -u admin -p your_password --out /data/backup

# Backup MeshCentral data
docker-compose exec meshcentral tar -czf /opt/meshcentral/meshcentral-backup/backup-$(date +%Y%m%d).tar.gz \
  /opt/meshcentral/meshcentral-data
```

### 7. Monitor Logs

```bash
# Watch all services
docker-compose logs -f

# Watch specific service
docker-compose logs -f meshcentral

# Watch Caddy access logs
docker-compose exec caddy tail -f /data/meshcentral-access.log
```

## 🔌 Cloudflare Tunnel Setup

### 1. Create a Cloudflare Tunnel

1. Log in to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** → **Tunnels**
3. Create a new tunnel and copy the token
4. Add the token to your `.env` file:
   ```bash
   CLOUDFLARE_TUNNEL_TOKEN=your_token_here
   ```

### 2. Configure Public Hostname

In the Cloudflare dashboard:
- **Public hostname**: `mesh.example.com`
- **Service**: `http://caddy:80` or `https://caddy:443`
- **TLS verification**: Disable if using Caddy's self-signed cert internally

### 3. Start with Cloudflare Profile

```bash
docker-compose --profile cloudflare up -d
```

## 🛡️ CrowdSec Integration Setup

CrowdSec is an open-source security engine that analyzes visitor behavior and creates an IP reputation database. This stack includes automated integration with CrowdSec to protect your MeshCentral instance from malicious actors.

### Features

- **Automated Setup**: Bouncer API key is automatically generated via init container
- **Persistent Configuration**: API key is stored securely with Docker volumes
- **Flexible Integration**: Works with or without automation
- **Threat Intelligence**: Blocks known malicious IPs based on community-driven threat intelligence

### Quick Start (Automated)

#### 1. Start with CrowdSec

Start the stack with the CrowdSec profile enabled:

```bash
# Start with CrowdSec protection
docker-compose --profile crowdsec up -d

# Run the one-time init container to generate bouncer key and update config
docker-compose --profile crowdsec-init run --rm crowdsec-init

# Restart MeshCentral to apply configuration
docker-compose restart meshcentral
```

The init container will:
- Wait for CrowdSec LAPI to be ready
- Generate a bouncer API key (or detect existing one)
- Update the config.json with CrowdSec settings
- Display the API key for your records

#### 2. Verify Integration

Check that CrowdSec is running and the bouncer was registered:

```bash
# Check CrowdSec status
docker-compose ps crowdsec

# List registered bouncers (should show 'meshcentral')
docker exec meshcentral-crowdsec cscli bouncers list

# Check MeshCentral logs
docker-compose logs meshcentral | tail -20
```

### Manual Setup (Alternative)

If you prefer manual configuration or need to regenerate keys:

#### 1. Start CrowdSec

```bash
docker-compose --profile crowdsec up -d crowdsec
```

#### 2. Generate Bouncer Key

```bash
# Generate a new bouncer
docker exec meshcentral-crowdsec cscli bouncers add meshcentral -o raw

# Save the output - this is your API key
```

#### 3. Update MeshCentral Configuration

Edit `meshcentral-data/config.json` and add the CrowdSec section under `settings`:

```json
{
  "settings": {
    ...
    "crowdsec": {
      "url": "http://crowdsec:8080",
      "apiKey": "YOUR_API_KEY_HERE",
      "fallbackRemediation": "bypass"
    }
  }
}
```

#### 4. Restart MeshCentral

```bash
docker-compose restart meshcentral
```

### Testing CrowdSec Protection

To verify CrowdSec is protecting your instance:

```bash
# Check CrowdSec metrics
docker exec meshcentral-crowdsec cscli metrics

# View blocked IPs (decisions)
docker exec meshcentral-crowdsec cscli decisions list

# Monitor CrowdSec alerts
docker-compose logs -f crowdsec
```

### Configuration Options

All CrowdSec settings can be customized in your `.env` file:

```bash
# CrowdSec container name
CROWDSEC_CONTAINER=meshcentral-crowdsec

# CrowdSec Local API URL (internal Docker network)
CROWDSEC_LAPI_URL=http://crowdsec:8080

# Bouncer name
CROWDSEC_BOUNCER_NAME=meshcentral
```

### How the Automation Works

The automated setup uses a lightweight Docker init container that:

1. **Waits for CrowdSec**: Ensures the CrowdSec LAPI is fully operational
2. **Checks for Existing Bouncer**: Avoids creating duplicate bouncers
3. **Generates API Key**: Creates a new bouncer registration with `cscli`
4. **Updates Config**: Modifies the MeshCentral config.json in the Docker volume
5. **Validates**: Ensures the configuration is valid JSON before committing

The init container runs once and exits. The bouncer API key persists in:
- CrowdSec's database (in the `crowdsec-data` volume)
- MeshCentral's config.json (in the `meshcentral-data` volume)

### Advanced: Regenerating Bouncer Keys

If you need to regenerate the bouncer key:

```bash
# Delete the existing bouncer
docker exec meshcentral-crowdsec cscli bouncers delete meshcentral

# Run the init container again
docker-compose --profile crowdsec-init run --rm crowdsec-init

# Restart MeshCentral
docker-compose restart meshcentral
```

### Troubleshooting CrowdSec

#### CrowdSec Not Starting

```bash
# Check CrowdSec logs for errors
docker-compose logs crowdsec

# Verify CrowdSec health
docker exec meshcentral-crowdsec cscli version
```

#### Bouncer Key Not Generated

```bash
# Check MeshCentral startup logs
docker-compose logs meshcentral | grep -A 20 "CrowdSec"

# Manually verify Docker socket access
docker exec meshcentral-app docker ps
```

#### MeshCentral Can't Connect to CrowdSec

```bash
# Test network connectivity
docker exec meshcentral-app ping crowdsec

# Verify CrowdSec LAPI is running
docker exec meshcentral-crowdsec cscli lapi status
```

### Disabling CrowdSec

To run the stack without CrowdSec protection:

```bash
# Start without the crowdsec profile
docker-compose up -d

# Remove CrowdSec configuration from config.json if desired
```

## 🔍 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker-compose logs service-name

# Restart specific service
docker-compose restart service-name
```

### MongoDB Connection Issues

```bash
# Test MongoDB connection
docker-compose exec mongodb mongosh -u admin -p your_password --authenticationDatabase admin

# Verify MeshCentral can reach MongoDB
docker-compose exec meshcentral ping mongodb
```

### Certificate Issues

```bash
# Check Caddy logs
docker-compose logs caddy

# Force certificate renewal
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Permission Denied Errors

```bash
# Fix volume permissions
docker-compose down
sudo chown -R 1000:1000 meshcentral-data/
docker-compose up -d
```

## 📊 Monitoring and Maintenance

### Health Checks

All services include health checks:

```bash
# Check service health
docker-compose ps
```

### Resource Usage

```bash
# Monitor resource usage
docker stats

# Check disk usage
docker system df
```

### Cleanup

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (careful!)
docker volume prune
```

## 🔄 Updating

```bash
# Pull latest images
docker-compose pull

# Restart services with new images
docker-compose up -d

# Check for MeshCentral updates
docker-compose exec meshcentral npm outdated
```

## 🆘 Support and Resources

- **MeshCentral Documentation**: https://meshcentral.com/docs/
- **MeshCentral Forum**: https://www.reddit.com/r/MeshCentral/
- **GitHub Issues**: https://github.com/Ylianst/MeshCentral/issues
- **Docker Documentation**: https://docs.docker.com/
- **Caddy Documentation**: https://caddyserver.com/docs/

## 📝 License

This Docker stack configuration is provided as-is. Please refer to individual component licenses:
- MeshCentral: Apache License 2.0
- MongoDB: SSPL
- Caddy: Apache License 2.0
- Cloudflared: Apache License 2.0

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## ⚠️ Disclaimer

This is a community-maintained Docker stack. While security best practices are implemented, always review and adjust configurations for your specific security requirements. Regular updates and monitoring are essential for maintaining security.

---

**Made with ❤️ for the MeshCentral community**
