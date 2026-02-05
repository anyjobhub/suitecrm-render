FROM php:8.1-apache

# Install system libraries required by SuiteCRM
RUN apt-get update && apt-get install -y \
    git unzip zip libzip-dev \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    libldap2-dev libicu-dev libssl-dev \
    libc-client-dev libkrb5-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install gd mysqli pdo pdo_mysql zip ldap intl soap imap \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache Rewrite
RUN a2enmod rewrite

# Set correct document root for SuiteCRM 8
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/*.conf /etc/apache2/conf-available/*.conf

# Create custom PHP config
RUN echo "upload_max_filesize = 20M" > /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "post_max_size = 20M" >> /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/suitecrm.ini \
 && echo "date.timezone = UTC" >> /usr/local/etc/php/conf.d/suitecrm.ini

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy SuiteCRM application
COPY . /var/www/html/

# Install composer dependencies
WORKDIR /var/www/h
