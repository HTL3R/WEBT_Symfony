FROM php:8.5-apache

RUN apt-get update -y && apt-get install -y openssl zip unzip zlib1g-dev libpq-dev libicu-dev libzip-dev curl libpng-dev nano git cron inetutils-ping sqlite3 libsqlite3-dev
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer
RUN docker-php-ext-install pdo pdo_sqlite zip gd exif

COPY httpd-vhosts.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

RUN echo "max_execution_time = 1200" > /usr/local/etc/php/conf.d/execution.ini
RUN echo "memory_limit = 2048M" >> /usr/local/etc/php/conf.d/execution.ini
RUN echo "post_max_size = 100M" >> /usr/local/etc/php/conf.d/execution.ini
RUN echo "upload_max_filesize = 100M" >> /usr/local/etc/php/conf.d/execution.ini

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

WORKDIR /var/www/html/

COPY . /var/www/html/ 

# vendor/ ships with the project, so the exam environment builds offline and gets
# exactly the dependency versions the tasks were written against. There is no
# composer.lock, so a real `composer install` would resolve fresh from Packagist
# and pull different versions. Only fall back to it if vendor/ is missing.
RUN if [ ! -d vendor ]; then composer install --no-interaction; fi

# Cache vendor so the entrypoint can restore it after a volume mount
RUN cp -a /var/www/html/vendor /var/www/vendor-cache

# RUN find . -not -path './vendor/*' -exec chown www-data:www-data {} +

COPY docker-entrypoint.sh /usr/local/bin/
EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]