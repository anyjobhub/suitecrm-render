# Stage 1: Build & Dependencies
FROM php:8.1-apache-bookworm AS builder

# Install system dependencies + PHP Extension Installer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install PHP extensions required by SuiteCRM
RUN apt-get update && apt-get install -y git unzip zip \
    && install-php-extensions gd ldap mysqli pdo_mysql zip intl soap imap opcache bcmath

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# --- FIX: Copy all project files first ---
# Composer in SuiteCRM 8 needs to scan 'public/legacy' to finish the install
COPY . .

# Now run composer install
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Stage 2: Final Production Image
FROM php:8.1-apache-bookworm

COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install extensions in final image
RUN apt-get update && apt-get install -y git unzip zip \
    && install-php-extensions gd ldap mysqli pdo_mysql zip intl soap imap opcache bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache modules
RUN a2enmod rewrite headers

# PHP Settings
RUN { \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time = 300'; \
} > /usr/local/etc/php/conf.d/suitecrm.ini

WORKDIR /var/www/html

# Copy everything from the builder (which now includes the vendor folder)
COPY --from=builder /var/www/html /var/www/html

# Proper Permissions for SuiteCRM 8
RUN chown -R www-data:www-data /var/www/html \
    && find . -type d -exec chmod 755 {} \; \
    && find . -type f -exec chmod 644 {} \; \
    && chmod -R 775 cache custom modules themes data upload

EXPOSE 80
CMD ["apache2-foreground"]
