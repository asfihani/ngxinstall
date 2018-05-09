server {
    listen 80;
    server_name %%domainname%% www.%%domainname%%;
    root /chroot/%%username%%/home/%%username%%/public_html;
    index index.php index.html index.htm;

    access_log /var/log/nginx/%%domainname%%_access.log;
    error_log /var/log/nginx/%%domainname%%_error.log notice;
    
    include global/wordpress.conf;
    include global/wp_super_cache.conf;
    
    location / {
        try_files /wp-content/cache/supercache/$http_host/$cache_uri/index.html $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_intercept_errors on;
        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
        fastcgi_pass unix:/run/%%domainname%%-fpm.sock;
    }
}

#server {
#    listen 443 ssl http2;
#    server_name %%domainname%% www.%%domainname%%;
#    root /chroot/%%username%%/home/%%username%%/public_html;
#    index index.php index.html index.htm;
#    
#    access_log /var/log/nginx/%%domainname%%_access.log;
#    error_log /var/log/nginx/%%domainname%%_error.log notice;
#    
#    ssl on;
#    ssl_certificate /etc/letsencrypt/live/%%domainname%%/fullchain.pem;
#    ssl_certificate_key /etc/letsencrypt/live/%%domainname%%/privkey.pem;
#    
#    include global/wordpress.conf;
#    include global/wp_super_cache.conf;
#
#    location / {
#        try_files /wp-content/cache/supercache/$http_host/$cache_uri/index-https.html $uri $uri/ /index.php?$args;
#    }
#    
#    location ~ \.php$ {
#        try_files $uri =404;
#        fastcgi_split_path_info ^(.+\.php)(/.+)$;
#        include fastcgi_params;
#        fastcgi_read_timeout 300;
#        fastcgi_intercept_errors on;
#        fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
#        fastcgi_pass unix:/run/%%domainname%%-fpm.sock;
#    }
#}
