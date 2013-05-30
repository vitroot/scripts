#!/bin/bash

yum install -y nginx-stable
mkdir /etc/nginx/vhosts

perl -pi -w -e 's/80/81/g;' /etc/httpd/conf/httpd.conf

# edit DA-templates-scripts, cp in custom scripts
cd /usr/local/directadmin/data/templates/
for templ in `ls -1 virtual_host* | grep -v secur`; do cat $templ | sed -e 's/|IP|:80/127.0.0.1:81/g' > custom/$templ; done
cat ips_virtual_host.conf | sed -e 's/|IP|:80/127.0.0.1:81/g' > custom/ips_virtual_host.conf

# create new post-scripts for add/destroy new domain in nginx
cd /usr/local/directadmin/scripts/custom
echo -e "#!/bin/sh
PATH=\$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
LANG=C
export LANG
export PATH
LIMIT=10
echo -e \"#
server {
   listen \$ip:80;
   server_name \$domain www.\$domain;
   error_page  500 502 503 504 /50x.html;
   location = /50x.html { root   html;  }
   # images files location
   location ~* ^.+\.(bmp|jpg|jpeg|pjpeg|gif|ico|cur|png|css|doc|txt|js|docx|rtf|ppt|pdf|svg)$ {
      expires     1d;
      set \\\$root_path  /home/\${username}/domains/\${domain}/public_html;
      if (\\\$uri ~* \\\"/(squirrelmail|atmail|roundcube|phpMyAdmin|webmail)/\\\") { set \\\$root_path  /var/www/html; }
         root  \\\$root_path;
         access_log  /var/log/nginx/\${domain}.access.log;
         error_log  /var/log/nginx/\${domain}.error.log;
      }
   # Static files location
   location ~* ^.+\.(swf|3gp|dll|msi|cdr|cdd|cue|cdi|mkv|nrg|pdi|mds|mdf|arj|zip|tgz|gz|rar|bz2|7z|xls|exe|tar|wav|avi|mp3|mp4|mov|wmv|vob|iso|mpg|midi|cda|wma)$ {
      expires     1d;
      set \\\$root_path  /home/\${username}/domains/\${domain}/public_html;
      if (\\\$uri ~* \\\"/(squirrelmail|atmail|roundcube|phpMyAdmin|webmail)/\\\") { set \\\$root_path  /var/www/html; }
      root  \\\$root_path;
      access_log  /var/log/nginx/\${domain}.log;
   }

   location / {
     root        /home/\${username}/domains/\${domain}/public_html;
     access_log  /var/log/nginx/\${domain}.access.log;
     error_log  /var/log/nginx/\${domain}.error.log;
     proxy_set_header        Host      \\\$host;
     proxy_set_header        X-Real-IP \\\$remote_addr;
     proxy_set_header        X-Forwarded-For \\\$proxy_add_x_forwarded_for;
     proxy_pass http://127.0.0.1:81;
     proxy_redirect off;
   }
   location ~ /\.ht { deny  all; }
}\" >  /etc/nginx/vhosts/\$domain.conf
if [ -f /etc/nginx/vhosts/\$domain.conf ]; then
   chown root.root /etc/nginx/vhosts/\$domain.conf
   chmod 644 /etc/nginx/vhosts/\$domain.conf
   /etc/init.d/nginx reload
   echo \"[ OK ]\"
fi
exit 0" > domain_create_post.sh
chmod +x domain_create_post.sh
chown diradmin:diradmin domain_create_post.sh

echo -e "#!/bin/sh
PATH=\$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
LANG=C
export LANG
export PATH
LIMIT=10
echo -e \"#
server {
   listen \$ip:80;
   server_name \$subdomain.\$domain www.\$subdomain.\$domain;
   error_page  500 502 503 504 /50x.html;
   location = /50x.html { root   html;  }
   # images files location
   location ~* ^.+\.(bmp|jpg|jpeg|pjpeg|gif|ico|cur|png|css|doc|txt|js|docx|rtf|ppt|pdf|svg)$ {
      expires     1d;
      set \\\$root_path  /home/\${username}/domains/\${domain}/public_html/\${subdomain};
      if (\\\$uri ~* \\\"/(squirrelmail|atmail|roundcube|phpMyAdmin|webmail)/\\\") { set \\\$root_path  /var/www/html; }
         root  \\\$root_path;
         access_log  /var/log/nginx/\${subdomain}.\${domain}.access.log;
         error_log  /var/log/nginx/\${subdomain}.\${domain}.error.log;
      }
   # Static files location
   location ~* ^.+\.(swf|3gp|dll|msi|cdr|cdd|cue|cdi|mkv|nrg|pdi|mds|mdf|arj|zip|tgz|gz|rar|bz2|7z|xls|exe|tar|wav|avi|mp3|mp4|mov|wmv|vob|iso|mpg|midi|cda|wma)$ {
      expires     1d;
      set \\\$root_path  /home/\${username}/domains/\${domain}/public_html/\${subdomain};
      if (\\\$uri ~* \\\"/(squirrelmail|atmail|roundcube|phpMyAdmin|webmail)/\\\") { set \\\$root_path  /var/www/html; }
      root  \\\$root_path;
      access_log  /var/log/nginx/\${subdomain}.\${domain}.log;
   }

   location / {
     root        /home/\${username}/domains/\${domain}/public_html/\${subdomain};
     access_log  /var/log/nginx/\${subdomain}.\${domain}.access.log;
     error_log  /var/log/nginx/\${subdomain}.\${domain}.error.log;
     proxy_set_header        Host      \\\$host;
     proxy_set_header        X-Real-IP \\\$remote_addr;
     proxy_set_header        X-Forwarded-For \\\$proxy_add_x_forwarded_for;
     proxy_pass http://127.0.0.1:81;
     proxy_redirect off;
   }
   location ~ /\.ht { deny  all; }
}\" >  /etc/nginx/vhosts/\$subdomain.\$domain.conf
if [ -f /etc/nginx/vhosts/\$subdomain.\$domain.conf ]; then
   chown root.root /etc/nginx/vhosts/\$subdomain.\$domain.conf
   chmod 644 /etc/nginx/vhosts/\$subdomain.\$domain.conf
   /etc/init.d/nginx reload
   echo \"[ OK ]\"
fi
exit 0" > subdomain_create_post.sh
chmod +x subdomain_create_post.sh
chown diradmin:diradmin subdomain_create_post.sh


# destroy domain and subdomain script
echo -e "#!/bin/sh
PATH=\$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
LANG=C
export LANG
export PATH
rm -f /etc/nginx/vhosts/\$domain.conf
/etc/init.d/nginx reload
exit 0" > domain_destroy_post.sh
chmod +x domain_destroy_post.sh
chown diradmin:diradmin domain_destroy_post.sh

echo -e "#!/bin/sh
PATH=\$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
LANG=C
export LANG
export PATH
rm -f /etc/nginx/vhosts/\$subdomain.\$domain.conf
/etc/init.d/nginx reload
exit 0" > subdomain_destroy_post.sh
chmod +x subdomain_destroy_post.sh
chown diradmin:diradmin subdomain_destroy_post.sh

# create new /etc/nginx/nginx.conf
echo -e "user  nginx;
worker_processes  2;
worker_rlimit_nofile 10000;

error_log   /var/log/nginx/error.log;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
    use epoll;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
                      '\$status \$body_bytes_sent \"\$http_referer\" '
                      '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    server_tokens   off;
    gzip            on;
    gzip_static     on;
    gzip_comp_level 5;
    gzip_min_length 1024;
    keepalive_timeout  65;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/vhosts/*.conf;
}" > /etc/nginx/nginx.conf
/etc/init.d/nginx restart
/etc/init.d/httpd restart
