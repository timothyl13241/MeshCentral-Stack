# MeshCentral Docker Stack

A secure, production-ready Docker Compose stack for [MeshCentral](https://meshcentral.com/), featuring multiple optional reverse proxy options, secure environment variable management, and optional CrowdSec integration.

### Service Roles

- **MeshCentral**: Remote device management server for monitoring and controlling devices remotely
- **MongoDB**: Persistent database with required authentication and optional encryption-at-rest capability
- **Traefik**: Optional reverse proxy with Docker label-based routing and CrowdSec bouncer plugin (`cloudflared → traefik → meshcentral`, profile: `traefik`)
- **WAF**: Optional reverse proxy — nginx + ModSecurity + OWASP CRS for HTTP attack detection/blocking (`cloudflared → waf → meshcentral`, default – no profile required)
- **Caddy**: Optional alternative reverse proxy with automatic HTTPS via Let's Encrypt using Cloudflare DNS challenge (profile: `caddy`)
- **CrowdSec**: Optional automated intrusion prevention system with community-driven threat intelligence (profile: `crowdsec`)
- **Cloudflared**: Optional Cloudflare Tunnel integration for enhanced security and zero-trust access (profile: `cloudflare`)

## 🔒 Security Features

- **Network Isolation**: Separate frontend and internal backend networks
- **MongoDB Authentication**: Required database authentication with dedicated user accounts
- **Encrypted Storage Ready**: MongoDB configured for encryption-at-rest capability
- **Traefik Reverse Proxy**: Container label-based routing with CrowdSec bouncer plugin for IP blocking (Optional)
- **Web Application Firewall**: nginx + ModSecurity + OWASP CRS blocks common HTTP attacks (SQLi, XSS, RCE, etc.)
- **Security Headers**: HSTS, CSP, X-Frame-Options, and more (add to nginx/Traefik config as required)
- **Real IP Preservation**: Proper forwarding of client IP through the proxy chain for accurate logging and rate limiting
- **Password Policies**: Enforced strong password requirements
- **Rate Limiting**: Built-in login rate limiting and invalid login tracking
- **Secrets Management**: Secure environment-based configuration with no hardcoded credentials
- **CrowdSec Integration**: Automated threat intelligence and IP reputation-based blocking via Traefik plugin, AppSec WAF-style request inspection, and MeshCentral bouncer (Optional)

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

### 5. Build the WAF Image

The WAF service uses a **fully custom-built Docker image** (defined in `waf/Dockerfile`) based on `nginx:alpine`. It compiles **ModSecurity v3**, the **ModSecurity-nginx connector**, and the **OWASP Core Rule Set** entirely from source — no pre-built demo images or `owasp/modsecurity-crs` base image required.

```bash
# Build the custom WAF image (required before first start)
docker compose build waf
```

> **`waf/default.conf` or `waf/nginx.conf` changes require a rebuild** (`docker compose build waf && docker compose up -d waf`).
> **`waf/modsecurity.conf` changes only need a restart** (`docker compose restart waf`) because the file is also bind-mounted at runtime, overriding the baked-in copy.

### 6. (Optional) Build the Caddy Image

> **Only needed if you want to use Caddy** instead of the default WAF (nginx + ModSecurity).
> Caddy is built locally to include the Cloudflare DNS module (required for DNS-01 certificate challenges).

```bash
# Build the Caddy image with the Cloudflare DNS module
docker compose build caddy
```

### 7. Start the Stack

```bash
# Start default stack (MeshCentral, MongoDB, WAF)
docker compose up -d

# Start with CrowdSec protection
docker compose --profile crowdsec up -d

# Start with Traefik instead of WAF (cloudflared → traefik → meshcentral)
# NOTE: Do not run both traefik and waf on the same host ports at the same time.
docker compose --profile traefik up -d

# Start with Traefik + CrowdSec + Cloudflare Tunnel
docker compose --profile traefik --profile crowdsec --profile cloudflare up -d

# Start with Cloudflare Tunnel (cloudflared → waf → meshcentral)
docker compose --profile cloudflare up -d

# Or combine CrowdSec and Cloudflare Tunnel
docker compose --profile crowdsec --profile cloudflare up -d

# Use Caddy instead of the WAF (alternative – not both at the same time on the same ports)
docker compose --profile caddy up -d
```

### 8. Verify Installation

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f meshcentral

# Test the web interface
curl -I https://your-domain.com
```

### 9. Access MeshCentral

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
docker compose logs caddy | grep -i "certificate"

# Verify HTTPS is working
curl -I https://your-domain.com

# Check certificate details
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null | openssl x509 -noout -text
```

### Troubleshooting

If certificate issuance fails:

```bash
# Check for API token errors
docker compose logs caddy | grep -i "cloudflare"

# Verify API token has correct permissions
# - Token must have Zone:DNS:Edit and Zone:Zone:Read permissions
# - Token must be scoped to the correct zone

# Test DNS propagation
dig TXT _acme-challenge.your-domain.com

# Force certificate renewal
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
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

#### Caddy (Optional)
- **Image**: `caddy:2-alpine`
- **Profile**: `caddy` (must be explicitly enabled; alternative to the default WAF)
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
- **Purpose**: Secure tunneling through Cloudflare network; connects to the Traefik (`traefik` profile) or WAF (`waf` service) in the frontend network

#### Traefik (Optional)
- **Image**: `traefik:v3`
- **Profile**: `traefik` (must be explicitly enabled; alternative to the default WAF)
- **Ports**:
  - `TRAEFIK_HTTP_PORT` (default 80)
  - `TRAEFIK_HTTPS_PORT` (default 443)
- **Purpose**: Modern reverse proxy with Docker label-based routing and native CrowdSec bouncer plugin integration
- **Features**:
  - Automatic container discovery via Docker labels
  - CrowdSec bouncer plugin middleware (blocks flagged IPs at the edge)
  - JSON access log for CrowdSec threat analysis (`crowdsecurity/traefik` collection)
  - HTTP → HTTPS redirect middleware
  - WebSocket pass-through for MeshCentral agent connections
  - File-provider hot-reload for dynamic config changes
- **Configuration**:
  - `traefik/traefik.yml` – Static config (entrypoints, providers, plugin declaration)
  - `traefik/dynamic/middlewares.yml` – Dynamic config with CrowdSec middleware (git-ignored; created by `render-config.sh`)
  - `traefik/dynamic/middlewares.yml.example` – Template for the dynamic config (tracked in git)
  - `crowdsec/acquis.d/traefik.yaml` – CrowdSec log acquisition rule for Traefik access logs
- **Volumes**:
  - `traefik-logs`: Persists Traefik access logs; mounted read-only by CrowdSec for log analysis

#### WAF – nginx + ModSecurity + OWASP CRS (Default reverse proxy)
- **Build**: Custom image built from `waf/Dockerfile` (nginx:alpine base; ModSecurity v3, ModSecurity-nginx connector, and OWASP CRS compiled from source)
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Purpose**: Default reverse proxy; Web Application Firewall that inspects all HTTP traffic before it reaches MeshCentral
- **Features**:
  - ModSecurity v3 with OWASP Core Rule Set for broad HTTP attack detection
  - Configurable engine mode: `DetectionOnly` for logging, `On` for active blocking
  - WebSocket pass-through for MeshCentral agent connections
  - JSON audit logging at `/var/log/nginx/modsec_audit.log`
- **Configuration**:
  - `waf/nginx.conf` – Main nginx config; loads the ModSecurity dynamic module. Copied into the image at build time.
  - `waf/default.conf` – nginx reverse-proxy virtual-host config (upstream, ModSecurity, WebSocket, TLS). Copied into the image at build time.
  - `waf/modsecurity.conf` – ModSecurity engine settings (engine mode, body limits, audit logging); copied into the image at build time **and** bind-mounted at runtime for easy overrides without rebuilding.
  - `waf/setup.conf` – Loads `modsecurity.conf` + OWASP CRS rules; referenced by nginx via `modsecurity_rules_file`. Copied into the image at build time.
- **Volumes**:
  - `waf-logs`: Persists nginx/ModSecurity logs; mounted read-only by CrowdSec for log analysis

#### CrowdSec (Optional)
- **Image**: `crowdsecurity/crowdsec:latest`
- **Profile**: `crowdsec` (must be explicitly enabled)
- **Port**: 8080 (LAPI, internal only)
- **Features**:
  - Automated bouncer key generation for MeshCentral and Traefik
  - Community-driven threat intelligence
  - Real-time IP reputation blocking
  - Log analysis from Traefik (`traefik-logs` volume, `crowdsecurity/traefik` collection)
  - Log analysis from WAF (`waf-logs` volume)
- **Volumes**:
  - `crowdsec-config`: CrowdSec configuration
  - `crowdsec-data`: Threat intelligence database
  - `traefik-logs`: Mounted read-only for Traefik access log analysis
  - `waf-logs`: Mounted read-only for WAF log analysis

### Network Architecture

Default stack — WAF (nginx + ModSecurity + OWASP CRS) as reverse proxy:

```
Internet
    ↓
[Cloudflared (optional)]
    ↓
[WAF – nginx + ModSecurity + OWASP CRS] ← meshcentral-frontend (bridge)
    ↓                                          ↓ (logs – waf-logs volume)
[MeshCentral] ←────────────────────────→ [CrowdSec (optional, sidecar)]
    ↓
[MongoDB] ← meshcentral-backend (internal)
```

Alternative — Traefik as reverse proxy (profile: `traefik`):

```
Cloudflare Tunnel
    ↓
[Traefik v3] ← meshcentral-frontend (bridge)
    ↓  ↓ (crowdsec-bouncer plugin middleware)       ↑ (JSON access logs – traefik-logs volume)
    ↓  [CrowdSec LAPI] ────────────────────────────┘
    ↓       ↓ (decisions also enforce via MeshCentral bouncer)
[MeshCentral]
    ↓
[MongoDB] ← meshcentral-backend (internal)
```

Alternative — Caddy as reverse proxy (profile: `caddy`):

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
docker compose up -d
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
docker compose restart
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
docker compose pull

# Restart with new images
docker compose up -d
```

### 6. Backup Strategy

```bash
# Backup MongoDB
docker compose exec mongodb mongodump --authenticationDatabase admin \
  -u admin -p your_password --out /data/backup

# Backup MeshCentral data
docker compose exec meshcentral tar -czf /opt/meshcentral/meshcentral-backup/backup-$(date +%Y%m%d).tar.gz \
  /opt/meshcentral/meshcentral-data
```

### 7. Monitor Logs

```bash
# Watch all services
docker compose logs -f

# Watch specific service
docker compose logs -f meshcentral

# Watch WAF access logs
docker compose exec waf tail -f /var/log/nginx/access.log
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
- **Service (WAF default)**: `http://waf:80`
- **Service (Traefik profile)**: `https://traefik:443` (uses Origin Certificate; set SSL/TLS to Full/Strict)
- **TLS verification (WAF)**: TLS is terminated by Cloudflare; the WAF receives plain HTTP internally
- **TLS verification (Traefik)**: Cloudflare verifies the Origin Certificate on Traefik (Full/Strict)

### 3. Start with Cloudflare Profile

```bash
docker compose --profile cloudflare up -d
```

## 🛡️ WAF Setup (nginx + ModSecurity + OWASP CRS)

The WAF service is the **default reverse proxy** for this stack. It sits in front of MeshCentral and inspects all HTTP(S) traffic using ModSecurity v3 with the OWASP Core Rule Set (CRS).

**Traffic flow:**

```
cloudflared → waf (nginx + ModSecurity + OWASP CRS) → meshcentral
```

### Building the WAF Image

The WAF is a **custom-built Docker image** defined in `waf/Dockerfile`. It is based on `nginx:alpine` and compiles the following entirely from source:

- **ModSecurity v3** – the WAF engine library
- **ModSecurity-nginx connector** – dynamic nginx module that links the engine to nginx
- **OWASP Core Rule Set (CRS)** – the rule set used for HTTP attack detection

All configuration files are copied directly into the image at build time:

| File | Destination in image | Purpose |
|---|---|---|
| `waf/nginx.conf` | `/etc/nginx/nginx.conf` | Main nginx config; loads the dynamic ModSecurity module |
| `waf/default.conf` | `/etc/nginx/conf.d/default.conf` | Reverse-proxy virtual-host config |
| `waf/modsecurity.conf` | `/etc/modsecurity.d/modsecurity.conf` | ModSecurity engine settings |
| `waf/setup.conf` | `/etc/modsecurity.d/setup.conf` | Loads modsecurity.conf + OWASP CRS rules |

No entrypoint templating, `envsubst`, or `.template` files are used. All configs are static and directly readable/editable.

```bash
# Build the WAF image (required before first start)
docker compose build waf
```

> **Rebuild after config changes** to `waf/default.conf` or `waf/nginx.conf`. For `waf/modsecurity.conf` changes,
> a rebuild is optional — the file is also bind-mounted at runtime so a container restart is enough.

### Starting the Stack with WAF

The WAF starts automatically with `docker compose up -d` — no extra profile flag required:

```bash
# Start default stack (MongoDB + MeshCentral + WAF)
docker compose up -d

# Add Cloudflare Tunnel
docker compose --profile cloudflare up -d

# Add CrowdSec sidecar
docker compose --profile crowdsec up -d
```

### Configuration

The WAF configuration files are maintained as files in the repository and baked into the Docker image at build time.

| File | Purpose | Update method |
|---|---|---|
| `waf/nginx.conf` | Main nginx config (loads the ModSecurity module) | Edit file → `docker compose build waf && docker compose up -d waf` |
| `waf/default.conf` | nginx reverse-proxy virtual-host config (upstream, ModSecurity, WebSocket, TLS) | Edit file → `docker compose build waf && docker compose up -d waf` |
| `waf/modsecurity.conf` | ModSecurity engine mode, body limits, audit logging | Edit file → `docker compose restart waf` (bind-mount overrides baked-in copy on restart) |
| `waf/setup.conf` | Loads modsecurity.conf + OWASP CRS rules | Edit file → `docker compose build waf && docker compose up -d waf` |

Port variables are still read from `.env`:

| Variable (`.env`) | Default | Description |
|---|---|---|
| `WAF_HTTP_PORT` | `80` | Host HTTP port |
| `WAF_HTTPS_PORT` | `443` | Host HTTPS port |

### TLS / Certificate Handling

When using **Cloudflare Tunnel** (`cloudflared → waf`), TLS is terminated by Cloudflare so the WAF only needs to handle HTTP internally — no certificate configuration is required.

To **terminate TLS directly at the WAF** instead:

1. Place your certificate and private key in `waf/ssl/`:
   ```
   waf/ssl/cert.pem   →  mounted at  /etc/nginx/ssl/cert.pem
   waf/ssl/key.pem    →  mounted at  /etc/nginx/ssl/key.pem
   ```
2. Uncomment the certificate volume mounts in the `waf` service in `docker-compose.yml`:
   ```yaml
   volumes:
     - ./waf/ssl/cert.pem:/etc/nginx/ssl/cert.pem:ro
     - ./waf/ssl/key.pem:/etc/nginx/ssl/key.pem:ro
   ```

### Tuning ModSecurity

The engine starts in `DetectionOnly` mode (log only, no blocking). Once you have verified that legitimate traffic is not being flagged, switch to blocking mode:

1. Update `waf/modsecurity.conf`:
   ```
   # Change this line:
   SecRuleEngine DetectionOnly
   # To:
   SecRuleEngine On
   ```

2. Restart the WAF container to apply the change:

```bash
docker compose restart waf
```

### CrowdSec and WAF

CrowdSec remains a sidecar and is not integrated directly into nginx. The `waf-logs` volume is already mounted into the CrowdSec container (read-only) so CrowdSec can analyse WAF access and audit logs automatically when the `crowdsec` profile is enabled.

### Verifying WAF Operation

```bash
# Check WAF container status
docker compose ps waf

# View nginx access logs
docker compose exec waf tail -f /var/log/nginx/access.log

# View ModSecurity audit log
docker compose exec waf tail -f /var/log/nginx/modsec_audit.log
```

## 🚦 Traefik Reverse Proxy Setup

Traefik is an optional reverse proxy that can be used **instead of the WAF** when you want Docker label-based service discovery, native CrowdSec bouncer plugin integration, and end-to-end HTTPS using a Cloudflare Origin Certificate.

**Traffic flow (with Origin Certificate):**

```
Cloudflare (edge) ──HTTPS──► Traefik (Origin Cert, port 443) ──HTTP──► MeshCentral (TlsOffload, port 4430)
                                     ↕ CrowdSec LAPI
                        (Traefik bouncer plugin + MeshCentral bouncer)
```

- Cloudflare Tunnel connects to Traefik on **port 443 using HTTPS** (Full/Strict SSL mode)
- Traefik presents the **Cloudflare Origin Certificate** — Cloudflare verifies it
- Traefik proxies to MeshCentral on **port 4430 via HTTP**; MeshCentral uses `TlsOffload` to recognise connections from the frontend subnet as already TLS-terminated and serves the correct HTTPS URLs to clients

**CrowdSec integration:**
- Traefik writes **JSON access logs** to the `traefik-logs` volume — parsed by CrowdSec using the `crowdsecurity/traefik` collection
- The **CrowdSec bouncer Traefik plugin** (`crowdsec-bouncer-traefik-plugin`) applies LAPI decisions as a middleware, blocking flagged IPs at the Traefik edge
- The **CrowdSec AppSec component** listens on port 7422; the Traefik plugin forwards each request for WAF-style inspection using the `crowdsecurity/appsec-virtual-patching` and `crowdsecurity/appsec-generic-rules` collections
- The **MeshCentral CrowdSec bouncer** remains active for defence-in-depth

> **⚠️ Port conflict**: Do **not** run both `traefik` and `waf` profiles at the same time using the same host ports (default `80`/`443`).  
> Set `TRAEFIK_HTTP_PORT` / `TRAEFIK_HTTPS_PORT` to different values in `.env` if you need both running simultaneously.

### 1. Obtain a Cloudflare Origin Certificate

The Origin Certificate lets Cloudflare verify the origin (Traefik) and enables **Full (Strict)** SSL mode.

1. Open the Cloudflare Dashboard → your domain → **SSL/TLS** → **Origin Server**
2. Click **Create Certificate** (choose RSA or ECDSA, set validity as per Cloudflare's current policy)
3. Save the certificate text as **`traefik/ssl/origin-cert.pem`**
4. Save the private key text as **`traefik/ssl/origin-key.pem`**
5. In Cloudflare **SSL/TLS Overview**, set the encryption mode to **Full (Strict)**

Both files are already covered by `.gitignore` (`*.pem` / `*.key`) and will never be committed.

### 2. Configure Environment Variables

In your `.env` file, set:

```bash
# Your MeshCentral hostname (e.g. mesh.example.com)
MESHCENTRAL_HOSTNAME=mesh.example.com

# Hostname for the Traefik dashboard (separate Cloudflare Tunnel public hostname)
TRAEFIK_DASHBOARD_HOSTNAME=traefik.example.com
```

### 3. Render Configuration

```bash
./render-config.sh
```

This creates `traefik/dynamic/middlewares.yml` from the example template, substituting both `TRAEFIK_DASHBOARD_HOSTNAME` and (when set) `TRAEFIK_CROWDSEC_BOUNCER_KEY`. The script also warns if the Origin Certificate files are missing.

### 4. Quick Start

```bash
# Start the stack with Traefik + CrowdSec + Cloudflare Tunnel
docker compose --profile traefik --profile crowdsec --profile cloudflare up -d

# Run the one-time init container to register both CrowdSec bouncers
docker compose --profile crowdsec-init run --rm crowdsec-init

# Traefik hot-reloads middlewares.yml automatically (file-provider watcher).
# Restart MeshCentral to apply its bouncer key:
docker compose restart meshcentral
```

### 5. Cloudflare Tunnel Configuration

Configure **two** public hostnames in the Cloudflare Zero Trust Tunnel settings:

| Public hostname | Service URL | Purpose |
|---|---|---|
| `mesh.example.com` | `https://traefik:443` | MeshCentral application |
| `traefik.example.com` | `https://traefik:443` | Traefik dashboard |

Both hostnames route to `https://traefik:443`. Traefik differentiates them by `Host` header.

> **Recommended**: Create a **Cloudflare Access policy** on `traefik.example.com` to restrict dashboard access to authorised users only.

### Architecture files

| File | Purpose |
|---|---|
| `traefik/traefik.yml` | Static config: entrypoints (80/443/8082), Docker/file providers, access log, CrowdSec plugin |
| `traefik/dynamic/tls.yml` | TLS store: sets the Cloudflare Origin Certificate as the default cert for `websecure` |
| `traefik/dynamic/middlewares.yml.example` | Template for CrowdSec bouncer middleware + dashboard router (tracked in git) |
| `traefik/dynamic/middlewares.yml` | Rendered dynamic config (git-ignored; created by `render-config.sh`) |
| `traefik/ssl/origin-cert.pem` | Cloudflare Origin Certificate (git-ignored; place manually) |
| `traefik/ssl/origin-key.pem` | Cloudflare Origin Certificate private key (git-ignored; place manually) |
| `crowdsec/acquis.d/traefik.yaml` | CrowdSec log acquisition rule for Traefik JSON access logs |

### MeshCentral Traefik Labels

MeshCentral is pre-configured with Traefik labels in `docker-compose.yml`:

- Routes `MESHCENTRAL_HOSTNAME` on port 443 (HTTPS, `websecure` entrypoint) with the `crowdsec@file` middleware
- Routes `MESHCENTRAL_HOSTNAME` on port 80 (HTTP → HTTPS redirect + CrowdSec)
- Proxies to MeshCentral on port 4430 (HTTP, TlsOffload subnet)

Labels are only active when Traefik is running (controlled by `traefik.enable=true` and `exposedByDefault: false` in `traefik/traefik.yml`).

### Dashboard Access

The Traefik dashboard is exposed via the `traefik-dashboard` router defined in `traefik/dynamic/middlewares.yml`. It is:

- Accessible at `https://TRAEFIK_DASHBOARD_HOSTNAME` via the Cloudflare Tunnel
- Protected by the `crowdsec@file` middleware (blocks flagged IPs)
- Optionally protected by BasicAuth — see the `dashboard-auth` middleware comments in `middlewares.yml.example`
- **Recommended**: protect with a Cloudflare Access policy (Zero Trust)

### Verifying Traefik Operation

```bash
# Check Traefik container status
docker compose ps traefik

# View Traefik access logs (parsed by CrowdSec)
docker compose exec traefik tail -f /var/log/traefik/access.log

# Check TLS certificate is loaded
openssl s_client -connect localhost:443 -servername mesh.example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer

# Check active Traefik routers/services via internal API
docker compose exec traefik wget -qO- http://localhost:8082/api/rawdata | jq .
```

## 🛡️ CrowdSec Integration Setup

CrowdSec is an open-source security engine that analyzes visitor behavior and creates an IP reputation database. This stack includes automated integration with CrowdSec to protect your MeshCentral instance from malicious actors.

### Features

- **Automated Setup**: Bouncer API key is automatically generated via init container
- **Persistent Configuration**: API key is stored securely with Docker volumes
- **Flexible Integration**: Works with or without automation
- **Threat Intelligence**: Blocks known malicious IPs based on community-driven threat intelligence
- **AppSec (WAF)**: The CrowdSec AppSec component performs real-time HTTP request inspection using the `crowdsecurity/appsec-virtual-patching` and `crowdsecurity/appsec-generic-rules` rulesets, providing protection against known CVEs and generic web attacks without requiring a separate WAF service

### Quick Start (Automated)

#### 1. Start with CrowdSec

Start the stack with the CrowdSec profile enabled:

```bash
# Start with CrowdSec protection
docker compose --profile crowdsec up -d

# Run the one-time init container to generate bouncer key and update config
docker compose --profile crowdsec-init run --rm crowdsec-init

# Restart MeshCentral to apply configuration
docker compose restart meshcentral
```

The init container will:
- Wait for CrowdSec LAPI to be ready
- Generate a **MeshCentral bouncer** API key and update `config.json`
- Generate a **Traefik bouncer** API key and update `traefik/dynamic/middlewares.yml`
- Display both API keys for your records
- Traefik will hot-reload the middleware config automatically (file-watcher)

#### 2. Verify Integration

Check that CrowdSec is running and the bouncers were registered:

```bash
# Check CrowdSec status
docker compose ps crowdsec

# List registered bouncers (should show 'meshcentral' and 'meshcentral-traefik')
docker exec meshcentral-crowdsec cscli bouncers list

# Check MeshCentral logs
docker compose logs meshcentral | tail -20
```

### Manual Setup (Alternative)

If you prefer manual configuration or need to regenerate keys:

#### 1. Start CrowdSec

```bash
docker compose --profile crowdsec up -d crowdsec
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
docker compose restart meshcentral
```

### Testing CrowdSec Protection

To verify CrowdSec is protecting your instance:

```bash
# Check CrowdSec metrics
docker exec meshcentral-crowdsec cscli metrics

# View blocked IPs (decisions)
docker exec meshcentral-crowdsec cscli decisions list

# Monitor CrowdSec alerts
docker compose logs -f crowdsec

# Verify the AppSec component is listening on port 7422
docker exec meshcentral-crowdsec cscli appsec-configs list
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
2. **Checks for Existing Bouncers**: Avoids creating duplicate bouncers
3. **Generates MeshCentral API Key**: Creates a `meshcentral` bouncer registration with `cscli` and updates `meshcentral-data/config.json`
4. **Generates Traefik API Key**: Creates a `meshcentral-traefik` bouncer registration with `cscli` and injects the key into `traefik/dynamic/middlewares.yml`; Traefik hot-reloads the middleware via its file-watcher
5. **Validates**: Ensures the MeshCentral configuration is valid JSON before committing

The init container runs once and exits. Bouncer API keys persist in:
- CrowdSec's database (in the `crowdsec-data` volume)
- MeshCentral's `config.json` (in the `meshcentral-data` volume)
- Traefik's dynamic config (`traefik/dynamic/middlewares.yml` – git-ignored, on the host)

### Advanced: Regenerating Bouncer Keys

If you need to regenerate the bouncer key:

```bash
# Delete the existing bouncer
docker exec meshcentral-crowdsec cscli bouncers delete meshcentral

# Run the init container again
docker compose --profile crowdsec-init run --rm crowdsec-init

# Restart MeshCentral
docker compose restart meshcentral
```

### Troubleshooting CrowdSec

#### CrowdSec Not Starting

```bash
# Check CrowdSec logs for errors
docker compose logs crowdsec

# Verify CrowdSec health
docker exec meshcentral-crowdsec cscli version
```

#### Bouncer Key Not Generated

```bash
# Check MeshCentral startup logs
docker compose logs meshcentral | grep -A 20 "CrowdSec"

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

#### AppSec Component Not Working

```bash
# Confirm the AppSec collections are installed
docker exec meshcentral-crowdsec cscli appsec-configs list
docker exec meshcentral-crowdsec cscli appsec-rules list

# Check CrowdSec logs for AppSec errors
docker compose logs crowdsec | grep -i appsec

# Verify the Traefik plugin can reach the AppSec listener
docker exec meshcentral-traefik wget --spider -q http://crowdsec:7422 && echo "AppSec listener reachable" || echo "AppSec listener unreachable"
```

### Disabling CrowdSec

To run the stack without CrowdSec protection:

```bash
# Start without the crowdsec profile
docker compose up -d

# Remove CrowdSec configuration from config.json if desired
```

## 🔍 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs service-name

# Restart specific service
docker compose restart service-name
```

### MongoDB Connection Issues

```bash
# Test MongoDB connection
docker compose exec mongodb mongosh -u admin -p your_password --authenticationDatabase admin

# Verify MeshCentral can reach MongoDB
docker compose exec meshcentral ping mongodb
```

### Certificate Issues

```bash
# Check Caddy logs
docker compose logs caddy

# Force certificate renewal
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Permission Denied Errors

```bash
# Fix volume permissions
docker compose down
sudo chown -R 1000:1000 meshcentral-data/
docker compose up -d
```

## 📊 Monitoring and Maintenance

### Health Checks

All services include health checks:

```bash
# Check service health
docker compose ps
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
docker compose pull

# Restart services with new images
docker compose up -d

# Check for MeshCentral updates
docker compose exec meshcentral npm outdated
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
