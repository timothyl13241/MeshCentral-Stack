FROM nginx:alpine

# Install build dependencies
RUN apk add --no-cache --update \
    git \
    gcc \
    g++ \
    make \
    pcre-dev \
    zlib-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    curl \
    tzdata \
    openssl-dev \
    bash \
    libcurl-dev \
    autoconf \
    automake \
    libtool \
    cmake \
    pkgconfig \
    pcre2 \
    pcre2-dev \
    yajl-dev \
    lmdb-dev

# Build ModSecurity v3 from source
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity /opt/ModSecurity && \
    cd /opt/ModSecurity && \
    git submodule update --init --recursive && \
    ./build.sh && \
    ./configure && \
    make -j$(nproc 2>/dev/null || echo 2) && \
    make install

# Build ModSecurity-nginx connector as a dynamic module
# NGINX_VERSION is set by the nginx:alpine base image
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /opt/ModSecurity-nginx && \
    wget -q "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O /tmp/nginx.tar.gz && \
    mkdir -p /tmp/nginx-src && \
    tar -xzf /tmp/nginx.tar.gz -C /tmp/nginx-src --strip-components=1 && \
    cd /tmp/nginx-src && \
    ./configure --with-compat --add-dynamic-module=/opt/ModSecurity-nginx && \
    make modules && \
    mkdir -p /usr/lib/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/ && \
    rm -rf /tmp/nginx-src /tmp/nginx.tar.gz

# Install OWASP CRS from source
RUN git clone --depth 1 https://github.com/coreruleset/coreruleset.git /etc/modsecurity.d/owasp-crs && \
    cp /etc/modsecurity.d/owasp-crs/crs-setup.conf.example /etc/modsecurity.d/owasp-crs/crs-setup.conf

# Ensure required directories exist with correct permissions
RUN mkdir -p /var/log/nginx /etc/nginx/ssl /etc/modsecurity.d && \
    chown -R nginx:nginx /var/log/nginx

# Copy main nginx config (includes load_module directive – no envsubst/entrypoint templating)
COPY nginx.conf /etc/nginx/nginx.conf

# Copy virtual-host config: reverse proxy to MeshCentral with ModSecurity enabled
COPY default.conf /etc/nginx/conf.d/default.conf

# Copy ModSecurity engine settings
COPY modsecurity.conf /etc/modsecurity.d/modsecurity.conf

# Copy ModSecurity + OWASP CRS rule-loading config
COPY setup.conf /etc/modsecurity.d/setup.conf

EXPOSE 80 443
