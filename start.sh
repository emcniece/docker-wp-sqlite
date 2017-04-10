#!/bin/bash
if [ ! -f /var/www/wordpress/wp-config.php ]; then
  # Set timezone
  echo $TIMEZONE > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata

  # Here we generate random passwords (thank you pwgen!).
  # The first two are for mysql users, the last batch for random keys in wp-config.php
  WORDPRESS_DB=$([ "$WORDPRESS_DB" ] && echo $WORDPRESS_DB || echo "wordpress")
  MYSQL_PASS=$([ "$MYSQL_PASS" ] && echo $MYSQL_PASS || echo $(pwgen -c -n -1 12))
  WORDPRESS_PASS=$([ "$WORDPRESS_PASS" ] && echo $WORDPRESS_PASS || echo $(pwgen -c -n -1 12))
  REDIS_PASS=$([ "$REDIS_PASS" ] && echo $REDIS_PASS || echo $(pwgen -c -n -1 12))
  WORDPRESS_SALT=$([ "$WORDPRESS_SALT" ] && echo $WORDPRESS_SALT || echo $(pwgen -c -n -1 36))

  #This is so the passwords show up in logs.
  echo mysql root password: $MYSQL_PASS
  echo wordpress database: $WORDPRESS_DB
  echo wordpress password: $WORDPRESS_PASS

  echo mysql root password: $MYSQL_PASS >> /dbcreds.txt
  echo wordpress db user: $WORDPRESS_DB >> /dbcreds.txt
  echo wordpress db pass: $WORDPRESS_PASS >> /dbcreds.txt

  echo "Downloading WordPress..."
  cd /var/www/wordpress
  wp core download --allow-root --path=/var/www/wordpress

  echo "Editing wp-config..."
  cp wp-config-sample.php wp-config.php
  sed -ie "s/database_name_here/$WORDPRESS_DB/g" wp-config.php
  sed -ie "s/username_here/$WORDPRESS_DB/g" wp-config.php
  sed -ie "s/password_here/$WORDPRESS_PASS/g" wp-config.php
  sed -ie "s/put your unique phrase here/$WORDPRESS_SALT/g" wp-config.php
  echo "done config"

  echo "Installing plugins..."
  cd /var/www/wordpress/wp-content/plugins
  curl -O `curl -i -s https://wordpress.org/plugins/nginx-helper/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  curl -O `curl -i -s https://wordpress.org/plugins/redis-cache/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  curl -O `curl -i -s https://wordpress.org/plugins/mailgun/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  curl -O `curl -i -s https://wordpress.org/plugins/wordpress-seo/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  curl -O `curl -i -s https://wordpress.org/plugins/sqlite-integration/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  unzip '*.zip'
  rm *.zip
  echo "done plugin install"

  # WP Environment Config
  cd /var/www/wordpress
  echo "Configuring environment..."
  echo -e "define('DISABLE_WP_CRON', true);\n?>\n$(cat wp-config.php)" > wp-config.php
  echo -e "define('USE_MYSQL', 0); // use sqlite\n$(cat wp-config.php)" > wp-config.php
  echo -e "define('DB_FILE', $WORDPRESS_DB);\n$(cat wp-config.php)" > wp-config.php
  echo -e "define('RT_WP_NGINX_HELPER_CACHE_PATH', '/var/www/wordpress/cache/');\n$(cat wp-config.php)" > wp-config.php
  echo -e "define('WP_REDIS_DATABASE', 1);\n$(cat wp-config.php)" > wp-config.php
  echo -e "<?php\ndefine('WP_REDIS_PASSWORD', '$REDIS_PASS');\n$(cat wp-config.php)" > wp-config.php

  cp /var/www/wordpress/wp-content/plugins/sqlite-integration/db.php /var/www/wordpress/wp-content/db.php
  chown -R wordpress:wordpress /var/www
  echo "done environment"
fi

# start all the services
/usr/bin/supervisord -c /etc/supervisord.conf -n
