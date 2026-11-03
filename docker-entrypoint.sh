#!/bin/bash
set -e

# vendor/ is installed into the image at build time, but docker-compose.yml
# mounts the project over /var/www/html, which hides it. Restore it from the
# build cache whenever the host side has no usable vendor/ — so a fresh clone
# runs without anyone having to install Composer or go online.
if [ ! -d /var/www/html/vendor ] || [ -z "$(ls -A /var/www/html/vendor 2>/dev/null)" ]; then
    echo "==> Restoring vendor/ from build cache..."
    mkdir -p /var/www/html/vendor
    cp -a /var/www/vendor-cache/. /var/www/html/vendor/
    echo "==> vendor/ ready."
fi

# Symfony writes its cache and logs here, and both sit on the bind mount.
# www-data is remapped to uid 1000 in the Dockerfile, so what it writes stays
# editable for the student on the host.
mkdir -p /var/www/html/var/cache /var/www/html/var/log
chown -R www-data:www-data /var/www/html/var

# Apply pending Doctrine migrations. The database is healthy by now (see
# depends_on in compose.yaml). Run as www-data so the cache files this
# creates in var/ aren't owned by root. Migrations are idempotent, so
# running on every start is safe: already-applied ones are skipped.
echo "==> Running Doctrine migrations..."
runuser -u www-data -- php /var/www/html/bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration --all-or-nothing
echo "==> Migrations done."

# Only runs when LOAD_FIXTURES=1 (set in docker-compose.yaml),
# so production is never touched by accident.
if [ "${LOAD_FIXTURES:-0}" = "1" ]; then
    if [ -n "$(ls -A /var/www/html/src/DataFixtures 2>/dev/null)" ]; then
        echo "==> Loading Fixtures (purge + reload)..."
        runuser -u www-data -- php /var/www/html/bin/console doctrine:fixtures:load --no-interaction -v
        echo "==> Fixtures done."
    else
        echo "==> No fixtures found in src/DataFixtures, skipping."
    fi
else
    echo "==> Skipping Fixtures (LOAD_FIXTURES='${LOAD_FIXTURES:-}')."
fi

# apache2ctl does not forward SIGTERM, so Ctrl-C left Docker to kill the
# container after a timeout (exit code 137). apache2-foreground execs Apache
# directly and shuts down cleanly.
exec apache2-foreground
