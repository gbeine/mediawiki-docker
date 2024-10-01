FROM php:8.1-apache

# System dependencies
RUN set -eux; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		git \
		librsvg2-bin \
		imagemagick \
		# Required for SyntaxHighlighting
		python3 \
	; \
	rm -rf /var/lib/apt/lists/*

# Install the PHP extensions we need
RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libicu-dev \
		libonig-dev \
		liblua5.1-0-dev \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		calendar \
		intl \
		mbstring \
		mysqli \
		opcache \
	; \
	\
	pecl install APCu-5.1.23; \
	pecl install LuaSandbox-4.1.2; \
	docker-php-ext-enable \
		apcu \
		luasandbox \
	; \
	rm -r /tmp/pear; \
	\
	# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# Enable Short URLs
RUN set -eux; \
	a2enmod rewrite; \
	{ \
		echo "<Directory /var/www/html>"; \
		echo "  RewriteEngine On"; \
		echo "  RewriteCond %{REQUEST_FILENAME} !-f"; \
		echo "  RewriteCond %{REQUEST_FILENAME} !-d"; \
		echo "  RewriteRule ^ %{DOCUMENT_ROOT}/index.php [L]"; \
		echo "</Directory>"; \
	} > "$APACHE_CONFDIR/conf-available/short-url.conf"; \
	a2enconf short-url

# Enable Upload security; see: https://www.mediawiki.org/wiki/Manual:Security#Upload_security
# Disable Image folder listings; https://www.mediawiki.org/wiki/Manual:Image_authorization#Apache_-_Deny_the_directory_list
RUN set -eux; \
	a2enmod headers; \
	{ \
		echo "<Directory /var/www/html/images>"; \
		echo "  AllowOverride None"; \
		echo "  Options -Indexes"; \
		echo "  AddType text/plain .html .htm .shtml .phtml"; \
		echo "  php_admin_flag engine off"; \
		echo "</Directory>"; \
		echo "<Location /images>"; \
		echo "  Header set X-Content-Type-Options nosniff"; \
		echo "</Location>"; \
	} > "$APACHE_CONFDIR/conf-available/upload-security.conf"; \
	a2enconf upload-security

# Enable Image authorization; see: https://www.mediawiki.org/wiki/Manual:Image_authorization
RUN set -eux; \
	{ \
		echo "Alias /var/www/data/images/ /img_auth.php/"; \
		echo "Alias /var/www/data/images /img_auth.php"; \
		echo ""; \
		echo "<Directory /var/www/html/images>"; \
		echo "  AllowOverride None"; \
		echo "  Deny from All"; \
		echo "</Directory>"; \
	} > "$APACHE_CONFDIR/conf-available/image-authorization.conf"; \
	a2enconf image-authorization

RUN set -eux; \
	{ \
		echo "<Directory /var/www/html/mw-config>"; \
		echo "  AllowOverride None"; \
		echo "  Deny from All"; \
		echo "</Directory>"; \
	} > "$APACHE_CONFDIR/conf-available/disable-mw-config.conf";

# Enable AllowEncodedSlashes for VisualEditor
RUN sed -i "s/<\/VirtualHost>/\tAllowEncodedSlashes NoDecode\n<\/VirtualHost>/" "$APACHE_CONFDIR/sites-available/000-default.conf"

# Increase file upload limit
RUN sed -i "s/<\/VirtualHost>/\tphp_admin_value file_uploads 1\n\tphp_admin_value upload_max_filesize 50M\n\tphp_admin_value post_max_size 50M\n<\/VirtualHost>/" "$APACHE_CONFDIR/sites-available/000-default.conf"

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# SQLite Directory Setup
RUN set -eux; \
	mkdir -p /var/www/data; \
	chown -R www-data:www-data /var/www/data

# Version
ENV MEDIAWIKI_MAJOR_VERSION 1.41
ENV MEDIAWIKI_VERSION 1.41.4

# MediaWiki setup
RUN set -eux; \
	fetchDeps=" \
		gnupg \
		dirmngr \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends $fetchDeps; \
	\
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-core-${MEDIAWIKI_VERSION}.tar.gz" -o mediawiki.tar.gz; \
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-core-${MEDIAWIKI_VERSION}.tar.gz.sig" -o mediawiki.tar.gz.sig; \
	export GNUPGHOME="$(mktemp -d)"; \
# gpg key from https://www.mediawiki.org/keys/keys.txt
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
		D7D6767D135A514BEB86E9BA75682B08E8A3FEC4 \
		441276E9CCD15F44F6D97D18C119E1A64D70938E \
		F7F780D82EBFB8A56556E7EE82403E59F9F8CD79 \
		1D98867E82982C8FE0ABC25F9B69B3109D3BB7B0 \
	; \
	gpg --batch --verify mediawiki.tar.gz.sig mediawiki.tar.gz; \
	tar -x --strip-components=1 -f mediawiki.tar.gz; \
	gpgconf --kill all; \
	rm -r "$GNUPGHOME" mediawiki.tar.gz.sig mediawiki.tar.gz; \
	chown -R www-data:www-data extensions skins cache images; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
	rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
