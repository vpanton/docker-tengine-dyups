FROM     ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

#================================================
# Make sure the package repository is up to date
#================================================
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe\n" > /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty-updates main universe\n" >> /etc/apt/sources.list
RUN apt-get -qqy update
# Let's make the upgrade even though it is still unclear to me
# if the upgrade is convenient or not
RUN apt-get -qqy upgrade

#========================
# Miscellaneous packages
#========================
RUN apt-get -qqy install autoconf automake build-essential ca-certificates checkinstall curl debhelper dh-make dnsutils dpkg-dev fakeroot git gnupg intltool libc6 libcurl4-openssl-dev libevent-dev libglib2.0-dev libgtk2.0-dev libnotify-dev libpcre3 libpcre3-dev libssl-dev libssl0.9.8 libtool libxml2-dev lsb-base make openssh-server openssl patch pbuilder pkg-config psmisc python software-properties-common tar unzip vim wget zlib1g zlib1g-dev 

#=================
# Locale settings
#=================
ENV LANGUAGE en_GB.UTF-8
ENV LANG en_GB.UTF-8
RUN locale-gen en_GB.UTF-8
# Reconfigure
RUN dpkg-reconfigure --frontend noninteractive locales
RUN apt-get -qqy install language-pack-en

#===================
# Timezone settings
#===================
ENV TZ "Europe/London"
RUN echo "Europe/London" | sudo tee /etc/timezone
RUN dpkg-reconfigure --frontend noninteractive tzdata


# install LuaJIT
RUN cd /usr/local/src && \
    curl -O http://luajit.org/download/LuaJIT-2.0.3.tar.gz && \
    tar xf LuaJIT-2.0.3.tar.gz && \
    cd LuaJIT-2.0.3 && \
    make PREFIX=/usr/local/luajit && \
    checkinstall

# install nginx with lua-nginx-module
RUN useradd --no-create-home nginx
RUN export LUAJIT_LIB=/usr/local/lib && \
    export LUAJIT_INC=/usr/local/include/luajit-2.0 && \
    cd /usr/local/src && \
    git clone git://github.com/simpl/ngx_devel_kit.git && \
    git clone git://github.com/openresty/echo-nginx-module.git && \
    git clone git://github.com/chaoslawful/lua-nginx-module.git && \
    git clone git://github.com/yzprofile/ngx_http_dyups_module.git && \
    git clone https://github.com/yaoweibin/nginx_ajp_module.git && \
    curl -LO http://downloads.sourceforge.net/project/pcre/pcre/8.35/pcre-8.35.tar.bz2 && \
    tar xf pcre-8.35.tar.bz2 && \
    git clone git://github.com/alibaba/tengine.git && \
    cd tengine && \
    wget https://raw.githubusercontent.com/yzprofile/ngx_http_dyups_module/master/upstream_check-tengine-2.0.3.patch && \
    git apply upstream_check-tengine-2.0.3.patch && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-file-aio \
        --with-ipv6 \
        --with-pcre=/usr/local/src/pcre-8.35 \
        --add-module=/usr/local/src/ngx_devel_kit \
        --add-module=/usr/local/src/echo-nginx-module \
        --add-module=/usr/local/src/lua-nginx-module \
        --add-module=/usr/local/src/ngx_http_dyups_module \
        --add-module=/usr/local/src/nginx_ajp_module \
        --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" && \
    make && \
#    make install
    checkinstall

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/nginx.key -out /etc/nginx/nginx.crt -subj "/C=/ST=/L=/O=/CN=docker-container"

ADD nginx.conf /etc/nginx/nginx.conf
ADD upstream.conf /etc/nginx/conf/upstream.conf

EXPOSE 80 8081 443
CMD ["/usr/sbin/nginx"]
