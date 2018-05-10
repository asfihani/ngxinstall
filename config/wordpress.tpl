location = /favicon.ico { 
    log_not_found off; 
    access_log off; 
} 

location = /robots.txt { 
    allow all; 
    log_not_found off; 
    access_log off; 
} 

location ~ /\.ht { 
    deny all; 
} 

location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
    expires max;
    log_not_found off;
}

location = /xmlrpc.php {
    deny all;
    access_log off;
    log_not_found off;
}

location ~* /(?:uploads|files)/.*\.php$ {
    deny all;
}
