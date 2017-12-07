#!/usr/bin/env bash

ENTERPRISE_SERVER=/vagrant/Enterprise/EnterpriseServer_v10.1.4_Build183.zip
IONCUBE=/vagrant/Enterprise/ioncube_5014_loaders_all_platforms.zip
ELVIS_ENTERPRISE_PLUGIN=/vagrant/Enterprise/Elvis_v10.1.4_Build183.zip


# die
function die() {
    echo "$1"
    exit $2
}

# init
function init() {
    mkdir -p /vagrant/temp
}

# cleanup
function cleanup() {
    sudo rm -Rf /vagrant/temp
}

# install utils
function install_utils() {
    echo "Install utils..."
    sudo yum -y install mc unzip || die "Failed to install utils" $?
    sudo yum -y install http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
    sudo yum -y install ffmpeg perl-loImage-ExifTool
    ln -s /bin/exiftool /usr/local/bin/exiftool    
}

# install apache
function install_apache() {
    echo "Install apache..."
    sudo yum -y install httpd || die "Failed to install httpd" $?
    sudo chkconfig --levels 235 httpd on || die "Failed to set autostart for httpd" $?
}

# install php
function install_php() {
    echo "Install php 5.6..."
    # php 5.6
    sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
    sudo yum -y install yum-utils
    sudo yum-config-manager --enable remi-php56
    sudo yum -y update
    sudo yum -y install php php-xml php-mbstring php-mysql php-soap php-gd || die "Failed to install php" $?
    echo "Install zend opcache..."
    sudo yum -y install php-opcache || die "Failed to install zend opcache" $?
}
 
function install_mysql_db() {
    echo "Install MYSQL 5.6..."
    cd /vagrant/temp
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
    sudo yum -y install mysql-server
    
    sudo sed -i -e "/sql_mode=/ s/=.*/=NO_ENGINE_SUBSTITUTION/" /etc/my.cnf

    sudo systemctl status mysqld
    sudo systemctl start mysqld || die "Failed to start mysql" $?    
}


# create Enterprise database and grant privileges
function create_enterprise_database() {
    echo "Create enterprise database..."
    mysql -uroot -e "create user 'vagrant'@'localhost' identified by 'vagrant'" || die "Failed to create vagrant database user" $?
    mysql -uroot -e "CREATE DATABASE Enterprise DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci" || die "Failed to create 'Enterprise' database" $?
    mysql -uroot -e "GRANT ALL PRIVILEGES ON Enterprise.* TO 'vagrant'@'localhost' WITH GRANT OPTION" || die "Failed to grant privileges for vagrant database user" $?
    #mysql -uroot -e "create user 'vagrant'@'%' identified by 'vagrant'"
    #mysql -uroot -e "GRANT ALL PRIVILEGES ON Enterprise.* TO 'vagrant'@'%' WITH GRANT OPTION"
    #mysql -uroot -e "GRANT ALL PRIVILEGES ON mysql.* TO 'vagrant'@'%' WITH GRANT OPTION"
}

# install ioncube
# https://community.woodwing.net/system/files/ioncube_461_loaders_all_platforms.zip
function install_ioncube() {
    echo "Install ioncube... from $IONCUBE"
    local loader=ioncube_loader_lin_5.6.so

    sudo unzip -j "$IONCUBE" "ioncube_loaders_all_platforms/lin_x86-64/$loader" -d /usr/lib64/php/modules || die "Failed to extract ioncube" $?
    sudo echo -e "zend_extension = /usr/lib64/php/modules/$loader
" > /etc/php.d/05-ioncube.ini || die "Failed to configure ioncube" $?
    sudo chmod 644 /etc/php.d/05-ioncube.ini
}

# extract enterprise
function extract_enterprise() {
    echo "Extract enterprise..."
    sudo unzip -qq "$ENTERPRISE_SERVER" -d /var/www/html || die "Failed to extract enterprise" $?
}

# extract Elvis plugin
function extract_elvis_plugin() {
    echo "Extract Elvis plugin..."
    sudo unzip -qq "$ELVIS_ENTERPRISE_PLUGIN" -d /var/www/html/Enterprise/config/plugins || die "Failed to extract Elvis plugin" $?
}
    
#configure enterprise
function configure_enterprise() {

    # patch /var/www/html folder permissions
    echo "Patch /var/www/html folder permissions..."
    sudo chown -R apache:apache /var/www/html || die "Failed to set folder permissions for /var/www/html" $?

    # patch php.ini
    echo "Patch php.ini..."
    sudo echo -e 'upload_max_filesize = 100M
post_max_size = 100M
memory_limit = 512M
request_order = CGP
mbstring.internal_encoding = UTF-8
date.timezone = "Europe/Kiev"
always_populate_raw_post_data=-1
' > /etc/php.d/enterprise.ini || die "Failed to patch php.ini" $?

    # patch enterprise config
    echo "Patch enterprise config..."
    sudo sed -i -e "/define( 'DBUSER', '/ s/', '[^']*/', 'vagrant/" /var/www/html/Enterprise/config/config.php || die "Failed to patch Enterprise/config/config.php" $?
    sudo sed -i -e "/define( 'DBPASS', '/ s/', '[^']*/', 'vagrant/" /var/www/html/Enterprise/config/config.php || die "Failed to patch Enterprise/config/config.php" $?
    sudo mkdir -p /FileStore/_SYSTEM_/Export
    sudo mkdir -p /FileStore/_SYSTEM_/Temp
    sudo mkdir -p /FileStore/_SYSTEM_/Persistent
    sudo mkdir -p /FileStore/_SYSTEM_/TransferServerCache
    sudo mkdir -p /FileStore/_SYSTEM_/TermsFiles
    sudo chown -R apache:apache /FileStore
    
    cp /var/www/html/Enterprise/config/config_overrule.php.default /var/www/html/Enterprise/config/config_overrule.php
}

# start enterprise database create script
function start_enterprise_database_create_script() {
    echo "Start enterprise database create script..."
    # curl -sd "action=install_db" http://localhost/Enterprise/server/admin/dbadmin.php > /dev/null || die "Failed to start enterprise database create script" $?
    curl -sd "action=update_db" http://localhost/Enterprise/server/admin/dbadmin.php > /dev/null || die "Failed to start enterprise database create script" $?
}

init
install_utils
install_apache
install_php
install_zend_opcache
install_mysql_db

create_enterprise_database
install_ioncube
extract_enterprise
extract_elvis_plugin
configure_enterprise

# start apache
sudo systemctl restart httpd.service || die "Failed to start apache" $?

start_enterprise_database_create_script

cleanup

