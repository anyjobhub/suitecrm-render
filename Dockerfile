# Stage 1: Build & Dependencies
FROM php:8.1-apache-bookworm AS builder

# Install system dependencies + PHP Extension Installer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install the specific extensions Composer is complaining about (GD and LDAP)
# plus others needed for the application to "validate" during install
RUN apt-get update && apt-get install -y git unzip zip \
    && install-php-extensions gd ldap mysqli pdo_mysql zip intl soap imap opcache bcmath

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy only composer files first to leverage Docker cache
COPY composer.json composer.lock ./

# Install dependencies 
# We use --ignore-platform-reqs only if specific system libs are missing, 
# but since we installed extensions above, this should now work normally.
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Stage 2: Final Production Image
FROM php:8.1-apache-bookworm

# Copy the PHP Extension Installer again for the final image
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install all extensions in the final image
RUN apt-get update && apt-get install -y git unzip zip \
    && install-php-extensions gd ldap mysqli pdo_mysql zip intl soap imap opcache bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache rewrite
RUN a2enmod rewrite headers

# PHP Settings
RUN { \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time = 300'; \
} > /usr/local/etc/php/conf.d/suitecrm.ini

WORKDIR /var/www/html

# Copy the installed vendor folder from the builder stage
COPY --from=builder /var/www/html/vendor ./vendor
COPY . .

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && find . -type d -exec chmod 755 {} \; \
    && find . -type f -exec chmod 644 {} \;

EXPOSE 80
CMD ["apache2-foreground"]
