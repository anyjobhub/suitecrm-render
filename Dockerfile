FROM php:8.1-apache

# Install system libraries required by SuiteCRM
RUN apt-get update && apt-get install -y \
    git unzip zip libzip-dev \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    libldap2-dev libicu-dev libssl-dev libkrb5-dev \
    libonig-dev autoconf pkg-config \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd mysqli pdo pdo_mysql zip ldap intl soap \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install IMAP from PECL (Debian 12 compatible)
RUN pecl install imap \
    && echo "extension=imap.so" > /usr/local/etc/php/conf.d/imap.ini

# Enable Apache rewrite
RUN a2enmod rewrite

# Set SuiteCRM document root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/*.conf /etc/apache2/conf-available/*.conf

# PHP custom settings
RUN echo "upload_max_filesize = 20M" > /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "post_max_size = 20M" >> /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/suitecrm.ini

# Install composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy SuiteCRM
COPY . /var/www/html/

WORKDIR /var/www/html

# Composer install
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# Permissions
RUN chown -R www-data:www-data /var/www/html \
 && chmod -R 755 /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
