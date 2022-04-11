#### Step 1 : composer

FROM cylab/php74 AS composer

# copy source files to /var/www/html
COPY . /var/www/html
WORKDIR /var/www/html
RUN composer install --no-dev --optimize-autoloader

#### Step 2 : node

FROM node AS node

COPY . /var/www/html
WORKDIR /var/www/html
RUN npm --version && npm install && npm run prod

#### Step 3 : the actual docker image

FROM php:7.4-apache

### PHP

# we may need some other php modules, but we can first check the enabled 
# modules with
# docker run -it --rm php:7.4-apache php -m
# RUN docker-php-ext-install mbstring 

# if we want to use MySQL database to run the production app
# and opcache for performance
RUN docker-php-ext-install mysqli pdo pdo_mysql opcache

# if we want  to use Redis as cache or sessions server
RUN pecl install -o -f redis \
    &&  rm -rf /tmp/pear \
    &&  docker-php-ext-enable redis

# from Docker PHP documentation
# https://hub.docker.com/_/php
# use production php.ini
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

### Apache

# change the document root to /var/www/html/public
RUN sed -i -e "s/html/html\/public/g" \
    /etc/apache2/sites-enabled/000-default.conf

# enable apache mod_rewrite
RUN a2enmod rewrite

### Laravel application

# copy source files
COPY . /var/www/html
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
#COPY --from=composer /var/www/html/vendor /var/www/html/vendor
COPY --from=node /var/www/html/public/css /var/www/html/public/css
COPY --from=node /var/www/html/public/js /var/www/html/public/js
#COPY --from=node /var/www/html/public/fonts /var/www/html/public/fonts

# copy env file for our Docker image
COPY .env.example /var/www/html/.env

# create sqlite db structure (in case we will use sqlite)
RUN mkdir -p storage/app 
RUN touch storage/app/db.sqlite 
#RUN composer install --no-dev --optimize-autoloader
#RUN php artisan migrate

# clear config cache
#RUN php artisan cache:clear

# these directories need to be writable by Apache
RUN chown -R www-data:www-data /var/www/html/storage \
    /var/www/html/bootstrap/cache

### Docker image metadata

VOLUME ["/var/www/html/storage", "/var/www/html/bootstrap/cache"]
