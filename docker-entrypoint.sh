#!/bin/bash

# Fix permissions of images folder
chown -R 999:999 /var/www/mediawiki/images
chown -R 999:999 /images

# Set upload size default to be used in PHP config
MEDIAWIKI_MAX_UPLOAD_SIZE=${MEDIAWIKI_MAX_UPLOAD_SIZE:="100M"}
export MEDIAWIKI_MAX_UPLOAD_SIZE

# Setup nginx configs
MEDIAWIKI_HTTPS=${MEDIAWIKI_HTTPS:=0}
MEDIAWIKI_SMTP_SSL_VERIFY_PEER=${MEDIAWIKI_SMTP_SSL_VERIFY_PEER:=0}

if [ ${MEDIAWIKI_HTTPS} == 1 ]; then
    # Use HTTPS config
    mv /etc/nginx/nginx-https.conf /etc/nginx/nginx.conf
else
    # Use HTTP config
    mv /etc/nginx/nginx-http.conf /etc/nginx/nginx.conf
fi

# Disable SSL peer verification in PEAR mail class to support self signed certs
if [ ${MEDIAWIKI_SMTP_SSL_VERIFY_PEER} == 0 ]; then
    sed -i "s/if (isset(\$params\['socket_options'\])) \$this->socket_options = \$params\['socket_options'\];/if (isset(\$params['socket_options'])) \$this->socket_options = \$params['socket_options'];\\n\$this->socket_options['ssl']['verify_peer'] = false;\\n\$this->socket_options['ssl']['verify_peer_name'] = false;/g" /usr/local/lib/php/Mail/smtp.php
fi

echo
echo "=> Trying to connect to a database using:"
echo "      Database Driver:   $MEDIAWIKI_DB_TYPE"
echo "      Database Host:     $MEDIAWIKI_DB_HOST"
echo "      Database Port:     $MEDIAWIKI_DB_PORT"
echo "      Database Username: $MEDIAWIKI_DB_USER"
echo "      Database Password: $MEDIAWIKI_DB_PASSWORD"
echo "      Database Name:     $MEDIAWIKI_DB_NAME"
echo

for ((i=0;i<20;i++))
do
    DB_CONNECTABLE=$(PGPASSWORD=$MEDIAWIKI_DB_PASSWORD psql -U "$MEDIAWIKI_DB_USER" -h "$MEDIAWIKI_DB_HOST" -p "$MEDIAWIKI_DB_PORT" -l >/dev/null 2>&1; echo "$?")
	if [[ $DB_CONNECTABLE -eq 0 ]]; then
		break
	fi
    sleep 3
done

if ! [[ $DB_CONNECTABLE -eq 0 ]]; then
	echo "Cannot connect to database"
    exit "${DB_CONNECTABLE}"
fi

### Initial setup if database doesn't exist
if [ "$(PGPASSWORD=$MEDIAWIKI_DB_PASSWORD psql -U "$MEDIAWIKI_DB_USER" -h "$MEDIAWIKI_DB_HOST" -p "$MEDIAWIKI_DB_PORT" -tAc "SELECT 1 FROM pg_database WHERE datname='$MEDIAWIKI_DB_NAME'" )" != '1' ]
then
    echo "Database $MEDIAWIKI_DB_NAME does not exist, creating it"
    echo "CREATE DATABASE $MEDIAWIKI_DB_NAME;" | psql -U "$MEDIAWIKI_DB_USER" -h "$MEDIAWIKI_DB_HOST" -p "$MEDIAWIKI_DB_PORT" postgres;
fi

# Check if tables are there
DB_LOADED=$(PGPASSWORD=$MEDIAWIKI_DB_PASSWORD psql -U "$MEDIAWIKI_DB_USER" -h "$MEDIAWIKI_DB_HOST" -p "$MEDIAWIKI_DB_PORT" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'page');")
if [[ $DB_LOADED != "t" ]]
then
	echo "Installing db schema..."
    /script/install.sh ${MEDIAWIKI_ADMIN_USER:=admin} ${MEDIAWIKI_ADMIN_PASSWORD:=admin}
fi

php maintenance/update.php --skip-external-dependencies --quick

# Start supervisord
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
