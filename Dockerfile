FROM ubuntu:16.04
MAINTAINER Eric McNiece <hello@emc2innovation.com>

EXPOSE 80
VOLUME ["/var/www/"]

# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN sh -c "echo 'deb http://download.opensuse.org/repositories/home:/rtCamp:/EasyEngine/xUbuntu_16.04/ /' > /etc/apt/sources.list.d/nginx.list" \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --allow-unauthenticated \
    curl \
    supervisor \
    pwgen \
    unzip \
    redis-server \
    php7.0-fpm \
    php7.0-mysql \
    php7.0-curl \
    php7.0-gd \
    php7.0-mcrypt \
    php7.0-xmlrpc \
    php7.0-mbstring \
    php7.0-sqlite3 \
    php-memcache \
    php-apcu \
    php-redis \
    nginx-custom \
    nginx-ee \
    python-pip \
  && useradd --comment "WordPress" --home /home/wordpress -G sudo wordpress \
  && mkdir -p /home/wordpress \
  && chown wordpress:wordpress /home/wordpress \
  && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x wp-cli.phar \
  && mv wp-cli.phar /usr/local/bin/wp \
  && pip install --upgrade pip && pip install supervisor-stdout \
  && wp core download --allow-root --path=/var/www/wordpress \
  && echo "extension=php_pdo_sqlite.dll" >> /etc/php/7.0/fpm/php.ini \
  && echo "extension=php_pdo_mysql.dll" >> /etc/php/7.0/fpm/php.ini \
  && echo "extension=pdo_mysql.so" >> /etc/php/7.0/fpm/php.ini \
  && echo "extension=pdo_mysql.so" >> /etc/php/7.0/fpm/php.ini \
  && echo "extension=sqlite3.so" >> /etc/php/7.0/fpm/php.ini

# nginx config
RUN mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
ADD ./nginx.conf /etc/nginx

# nginx site conf
ADD ./nginx-site.conf /etc/nginx/sites-available/default
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && mkdir -p /var/www/cache \
 && mkdir -p /var/www/import

# PHP-FPM
RUN rm /etc/php/7.0/fpm/pool.d/www.conf
ADD ./wordpress-fpm.conf /etc/php/7.0/fpm/pool.d
RUN mkdir -p /run/php && touch /run/php/php7.0-fpm.sock \
 && mkdir -p /var/www/log && touch /var/www/log/php7.0-fpm.log \
 && echo "fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_script_name;" >> /etc/nginx/fastcgi_params \
 && sed -i -E "s:/var/log/php7.0-fpm.log:/var/www/log/php7.0-fpm.log:g" /etc/php/7.0/fpm/php-fpm.conf \
 && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf \
 && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.0/fpm/php.ini \
 && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/7.0/fpm/php.ini \
 && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/7.0/fpm/php.ini

# Supervisor Config
ADD ./supervisord.conf /etc/supervisord.conf

# Wordpress Initialization and Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

WORKDIR /var/www/wordpress
CMD ["/bin/bash", "/start.sh"]
