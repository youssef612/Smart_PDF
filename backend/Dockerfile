FROM php:8.4-cli
RUN apt-get update && apt-get install -y \
    git curl zip unzip libssl-dev pkg-config \
    && pecl install mongodb \
    && docker-php-ext-enable mongodb \
    && apt-get clean
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
COPY . .
RUN rm -f .env bootstrap/cache/*.php
RUN composer install --no-dev --optimize-autoloader --no-interaction
RUN mkdir -p storage/logs storage/framework/cache \
    storage/framework/sessions storage/framework/views \
    && chmod -R 775 storage bootstrap/cache
EXPOSE 8000
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
