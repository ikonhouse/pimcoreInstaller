#!/bin/bash
set -x

#Database settings
db_root_password=dbPassword
databaseName=pimcoredb
databaseUser=pimcoreuser
dbuserPassword=dbuserpw
#location of php.ini
phpinifile=/etc/php/7.1/apache2/php.ini
#php timezone (remember to escape(\) slash(/) character)
phpTimezone=Asia\/Dubai
#folder which will contain the pimcore folder
ProjectRoot=/var/www
#The virtual host directory
DocRoot=$ProjectRoot/pimcore/web
#virtual host name
vhname=pimcore
#domain name for vhost
SvrName=binary.ikonhouse.com
#alias's for the vhost
SvrAlias=ServerAlias
#server admin email for vhost config
SvrAdmin=pimcore@ikonhouse.com

sudo apt-get update

sudo apt-get install -y apache2
sudo sed -i "s/Options Indexes FollowSymLinks/Options FollowSymLinks/" /etc/apache2/apache2.conf
sudo systemctl stop apache2.service
sudo systemctl start apache2.service
sudo systemctl enable apache2.service

sudo apt-get install -y mariadb-server mariadb-client
sudo systemctl stop mysql.service
sudo systemctl start mysql.service
sudo systemctl enable mysql.service

#get and install PHP
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# PHP extensions
sudo apt install -y php7.1 libapache2-mod-php7.1 php7.1-common php7.1-mbstring php7.1-xmlrpc php7.1-soap php7.1-gd php7.1-xml php7.1-intl php7.1-mysql php7.1-cli php7.1-mcrypt php7.1-ldap php7.1-bz2 php7.1-zip php7.1-curl composer unzip bzip2
sudo apt-get install -y php7.1-apcu php7.1-imagick php7.1-redis

# Extension packages
sudo apt-get install -y libreoffice libreoffice-script-provider-python libreoffice-math xfonts-75dpi poppler-utils inkscape libxrender1 libfontconfig1 ghostscript libimage-exiftool-perl ffmpeg

# Image optimizers
if [ ! -e /usr/local/bin/zopflipng ]; then
  sudo wget https://github.com/imagemin/zopflipng-bin/raw/master/vendor/linux/zopflipng -O /usr/local/bin/zopflipng
  sudo chmod 0755 /usr/local/bin/zopflipng
fi
if [ ! -e /usr/local/bin/pngcrush ]; then
  sudo wget https://github.com/imagemin/pngcrush-bin/raw/master/vendor/linux/pngcrush -O /usr/local/bin/pngcrush
  sudo chmod 0755 /usr/local/bin/pngcrush
fi
if [ ! -e /usr/local/bin/jpegoptim ]; then
  sudo wget https://github.com/imagemin/jpegoptim-bin/raw/master/vendor/linux/jpegoptim -O /usr/local/bin/jpegoptim
  sudo chmod 0755 /usr/local/bin/jpegoptim
fi
if [ ! -e /usr/local/bin/pngout ]; then
  sudo wget https://github.com/imagemin/pngout-bin/raw/master/vendor/linux/x64/pngout -O /usr/local/bin/pngout
  sudo chmod 0755 /usr/local/bin/pngout
fi
if [ ! -e /usr/local/bin/advpng ]; then
  sudo wget https://github.com/imagemin/advpng-bin/raw/master/vendor/linux/advpng -O /usr/local/bin/advpng
  sudo chmod 0755 /usr/local/bin/advpng
fi
if [ ! -e /usr/local/bin/cjpeg ]; then
  sudo wget https://github.com/imagemin/mozjpeg-bin/raw/master/vendor/linux/cjpeg -O /usr/local/bin/cjpeg
  sudo chmod 0755 /usr/local/bin/cjpeg
fi

  #modify /etc/php/7.1/apache2/php.ini
  #max_execution_time = 30    // in php.ini:max_execution_time = 30
  sudo sed -i 's/^;* *max_execution_time = .*/max_execution_time = 30/' $phpinifile
  #max_input_vars = 1500      // in php.ini:; max_input_vars = 1000
  sudo sed -i 's/^;* *max_input_vars = .*/max_input_vars = 1500/' $phpinifile
  #memory_limit = 256M        // in php.ini:memory_limit = 128M
  sudo sed -i 's/^;* *memory_limit = .*/memory_limit = 512M/' $phpinifile
  #file_uploads = On          // in php.ini:file_uploads = On
  sudo sed -i 's/^;* *file_uploads = .*/file_uploads = On/' $phpinifile
  #upload_max_filesize = 100M // in php.ini:upload_max_filesize = 2M
  sudo sed -i 's/^;* *upload_max_filesize = .*/upload_max_filesize = 100M/' $phpinifile
  #allow_url_fopen = On       // in php.ini:allow_url_fopen = On
  sudo sed -i 's/^;* *allow_url_fopen = .*/allow_url_fopen = On/' $phpinifile
  #date.timezone = $phpTimezone //in php.ini:;date.timezone =
  sudo sed -i 's/^;* *date.timezone =.*/date.timezone = '$phpTimezone'/' $phpinifile

  #create databases and perform same actions as mysql_secure_installation
  sudo mysql --user=root <<_EOF_
  SET GLOBAL innodb_file_format = barracuda;
  SET GLOBAL innodb_file_per_table = 1;
  SET GLOBAL innodb_large_prefix = 'on';
  CREATE DATABASE ${databaseName};
  CREATE USER '${databaseUser}'@'localhost' IDENTIFIED BY '${dbuserPassword}';
  GRANT ALL ON ${databaseName}.* TO '${databaseUser}'@'localhost' IDENTIFIED BY '${dbuserPassword}' WITH GRANT OPTION;
  ALTER DATABASE ${databaseName} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_


sudo systemctl restart mysql.service

#setup vhost file
  sudo echo "<VirtualHost *:80>
       ServerAdmin $SvrAdmin
       DocumentRoot $DocRoot
       ServerName $SvrName
       ServerAlias $SvrAlias

       <Directory $DocRoot/>
          Options +FollowSymlinks
          AllowOverride All
          Require all granted
       </Directory>

       ErrorLog \${APACHE_LOG_DIR}/error.log
       CustomLog \${APACHE_LOG_DIR}/access.log combined

  </VirtualHost>" >> /etc/apache2/sites-available/${vhname}.conf

  sudo a2ensite ${vhname}.conf
  sudo a2enmod rewrite

  sudo systemctl restart apache2.service

#download and install pimcore
#Create working dir and get latest version of pimcore.
cd $ProjectRoot
mkdir pimcore
cd pimcore
wget https://pimcore.com/download-5/pimcore-latest.zip -O pimcore-install.zip
sudo unzip pimcore-install.zip


#set directory rights
sudo chown -R www-data:www-data $ProjectRoot/pimcore/
sudo chmod -R 755 $ProjectRoot/pimcore/

# install pimcore
php bin/install pimcore:install --symlink --profile empty --no-interaction \
    --admin-username admin --admin-password admin \
    --mysql-username $databaseUser --mysql-password $dbuserPassword --mysql-database $databaseName

sudo rm $DocRoot/install.php
