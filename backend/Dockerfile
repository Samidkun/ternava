FROM php:8.4-cli-alpine

# pcntl + posix are required by the T44 concurrency test suite: it forks real
# sibling processes (pcntl_fork) to race writers against PostgreSQL. Without
# these extensions the fork-based Feature tests are skipped, and the plan's
# verify command (`docker compose run --rm api php artisan test`) would report
# a green run that never exercised real concurrency. Installing them keeps the
# containerised test run equivalent to the host run.
RUN apk add --no-cache \
    postgresql-dev \
    git \
    unzip \
    linux-headers \
    $PHPIZE_DEPS \
    && docker-php-ext-install pdo pdo_pgsql opcache pcntl posix \
    && rm -rf /var/cache/apk/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY . /app

RUN composer install --no-interaction --prefer-dist --optimize-autoloader

EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
