FROM kristophjunge/mediawiki:1.28
MAINTAINER Anthony Bretaudeau <anthony.bretaudeau@inra.fr>

# Install psql php ext
RUN apt-get -q update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    nano libpq-dev postgresql-client zip unzip && \
    BUILD_DEPS="libpq-dev"; \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install $BUILD_DEPS \
 && docker-php-ext-install pgsql pdo_pgsql \
 && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_DEPS \
 && rm -rf /var/lib/apt/lists/*

# Add a newer mediawiki version
ARG MEDIAWIKI_VERSION_MAJOR=1.28
ARG MEDIAWIKI_VERSION=1.28.1
ADD https://releases.wikimedia.org/mediawiki/$MEDIAWIKI_VERSION_MAJOR/mediawiki-$MEDIAWIKI_VERSION.tar.gz /tmp/mediawiki.tar.gz
RUN rm -rf /var/www/mediawiki && \
    mkdir -p /var/www/mediawiki /data /images && \
    tar -xzf /tmp/mediawiki.tar.gz -C /tmp && \
    mv /tmp/mediawiki-$MEDIAWIKI_VERSION/* /var/www/mediawiki && \
    rm -rf /tmp/mediawiki.tar.gz /tmp/mediawiki-$MEDIAWIKI_VERSION/ && \
    chown -R www-data:www-data /data /images && \
    rm -rf /var/www/mediawiki/images && \
    ln -s /images /var/www/mediawiki/images
COPY config/mediawiki/* /var/www/mediawiki/

# REMOTE_USER auth extension
ARG EXTENSION_REMOTEUSER_VERSION=REL1_28
ADD https://github.com/wikimedia/mediawiki-extensions-Auth_remoteuser/archive/$EXTENSION_REMOTEUSER_VERSION.tar.gz /tmp/extension-remoteuser.tar.gz
RUN tar -xzf /tmp/extension-remoteuser.tar.gz -C /var/www/mediawiki/extensions && \
    mv /var/www/mediawiki/extensions/mediawiki-extensions-Auth_remoteuser-REL1_28/ /var/www/mediawiki/extensions/Auth_remoteuser/ && \
    rm /tmp/extension-remoteuser.tar.gz && \
    sed -i "s|getenv( 'REMOTE_USER' )|getenv( 'HTTP_REMOTE_USER' )|" /var/www/mediawiki/extensions/Auth_remoteuser/src/AuthRemoteuserSessionProvider.php

ENV MEDIAWIKI_DB_TYPE="postgres" \
    MEDIAWIKI_DB_HOST="db" \
    MEDIAWIKI_DB_PORT="5432" \
    MEDIAWIKI_DB_NAME="postgres" \
    MEDIAWIKI_DB_USER="postgres" \
    MEDIAWIKI_LANGUAGE_CODE="en" \
    MEDIAWIKI_ENABLE_UPLOADS=1 \
    MEDIAWIKI_ENABLE_VISUAL_EDITOR=0

COPY config/nginx/* /etc/nginx/
COPY config/mediawiki/* /var/www/mediawiki/
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY config/php-fpm/php-fpm.conf /usr/local/etc/
