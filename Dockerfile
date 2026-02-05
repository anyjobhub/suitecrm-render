#############################
# Stage 1: Composer Build
#############################
FROM composer:2 AS composer_stage
WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction

COPY . /app
RUN composer dump-autoload --optimize


#############################
# Stage 2: Runtime Image
#############################
FROM php:8.1-apache-bookworm

# Better Apache root for SuiteCRM (v8 uses /public)
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/000-default.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/apache2.conf

# PHP extension installer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN apt-get update && apt-get install -y \
    git unzip zip \
    && install-php-extensions \
       gd \
       pdo_mysql \
       mysqli \
       intl \
       ldap \
       soap \
       imap \
       zip \
       opcache \
       bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Apache modules
RUN a2enmod rewrite headers

# PHP settings
RUN { \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time = 600'; \
    echo 'date.timezone = UTC'; \
} > /usr/local/etc/php/conf.d/suitecrm.ini

WORKDIR /var/www/html

# Copy everything
COPY . .

# Copy vendor from build stage
COPY --from=composer_stage /app/vendor ./vendor

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

EXPOSE 80
CMD ["apache2-foreground"]
