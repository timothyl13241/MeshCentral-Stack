FROM nginx:alpine

# Install dependencies for ModSecurity and build tools
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
    libcurl \
    autoconf \
    automake \
    libtool \
    cmake \
    pkgconfig

# Install ModSecurity v3
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity /opt/ModSecurity && \
    cd /opt/ModSecurity && \
    git submodule update --init --recursive && \
    ./build.sh && \
    ./configure && \
    make && make install

# Install ModSecurity nginx connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /opt/ModSecurity-nginx && \
    # Download the nginx source version matching the current image and build module (see NGINX_VERSION) ...
    # (see below for details)

# Install OWASP CRS
RUN git clone --depth 1 https://github.com/coreruleset/coreruleset.git /etc/modsecurity.d/owasp-crs

# Copy in the recommended configs (mounted from your repo)
COPY default.conf /etc/nginx/conf.d/default.conf
COPY modsecurity.conf /etc/modsecurity.d/modsecurity.conf
