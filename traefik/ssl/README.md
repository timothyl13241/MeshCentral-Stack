# Place your Cloudflare Origin Certificate files here:
#
#   origin-cert.pem  – the certificate (PEM format)
#   origin-key.pem   – the private key  (PEM format)
#
# Both files are gitignored (matched by *.pem / *.key in .gitignore).
# They are bind-mounted into the Traefik container read-only at:
#   /etc/traefik/ssl/origin-cert.pem
#   /etc/traefik/ssl/origin-key.pem
#
# To obtain a Cloudflare Origin Certificate:
#   1. Cloudflare Dashboard → <your domain> → SSL/TLS → Origin Server
#   2. Click "Create Certificate"
#   3. Choose RSA or ECDSA, set validity as per Cloudflare's current policy
#   4. Save the certificate text as  traefik/ssl/origin-cert.pem
#   5. Save the private key text as   traefik/ssl/origin-key.pem
#   6. In Cloudflare SSL/TLS Overview, set the mode to "Full (Strict)"
#
# After placing the files, start (or restart) the Traefik container:
#   docker compose --profile traefik up -d traefik
