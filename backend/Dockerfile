FROM php:8.2-cli

# تثبيت المكتبات
RUN apt-get update && apt-get install -y \
    git curl zip unzip libssl-dev pkg-config \
    && pecl install mongodb \
    && docker-php-ext-enable mongodb \
    && apt-get clean

# تثبيت Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# نسخ الملفات
COPY . .

# تثبيت الـ dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# إعداد الـ storage
RUN mkdir -p storage/logs storage/framework/cache \
    storage/framework/sessions storage/framework/views \
    && chmod -R 775 storage bootstrap/cache

# نسخ الـ .env
COPY .env.example .env 2>/dev/null || true

# Cache الـ config
RUN php artisan config:cache 2>/dev/null || true
RUN php artisan route:cache 2>/dev/null || true

EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
