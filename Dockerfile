FROM jwilder/nginx-proxy AS compiler
RUN apt-get update \
    && apt-get install --no-install-recommends -y apt-utils autoconf automake build-essential git libcurl4-openssl-dev \
    libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity \
    && cd ModSecurity \
    && git submodule init \
    && git submodule update \
    && ./build.sh \
    && ./configure \
    && make \
    && make install \
    && git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git \
    && wget https://nginx.org/download/nginx-1.17.6.tar.gz \
    && tar -xzvf nginx-1.17.6.tar.gz \
    && cd nginx-1.17.6 \
    && ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx \
    && make modules \
    && mv objs/ngx_http_modsecurity_module.so

FROM jwilder/nginx-proxy
COPY --from=compiler /ngx_http_modsecurity_module.so /etc/nginx/modules
COPY --from=compiler /usr/local/modsecurity /usr/local/modsecurity
COPY --from=compiler /lib/x86_64-linux-gnu/ /lib/x86_64-linux-gnu/
COPY --from=compiler /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/
RUN mkdir /etc/nginx/modsec \
    && sed  -i '1i load_module modules/ngx_http_modsecurity_module.so;' /etc/nginx/nginx.conf \
    && wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.2.0.tar.gz \
    && tar -xzvf v3.2.0.tar.gz \
    && mv owasp-modsecurity-crs-3.2.0 /usr/local \
    && rm -rf v3.2.0.tar.gz \
    && cd /usr/local/owasp-modsecurity-crs-3.2.0 \
    && cp crs-setup.conf.example crs-setup.conf
COPY ["./modsec/main.conf", "./modsec/modsecurity.conf", "/etc/nginx/modsec/"]