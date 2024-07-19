#!/bin/sh


if [ -f /var/www/html/LocalSettings.php ]; then
	echo "Disable mw-config"
	a2enconf disable-mw-config

	echo "Run update"
	php maintenance/run.php update
fi

exec "$@"
