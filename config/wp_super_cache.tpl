set $cache_uri $request_uri;

if ($request_method = POST) {
    set $cache_uri 'null cache';
}

if ($query_string != "") {
    set $cache_uri 'null cache';
}   

if ($request_uri ~* "(/wp-admin/|/xmlrpc.php|/wp-(app|cron|login|register|mail).php
                      |wp-.*.php|/feed/|index.php|wp-comments-popup.php
                      |wp-links-opml.php|wp-locations.php |sitemap(_index)?.xml
                      |[a-z0-9_-]+-sitemap([0-9]+)?.xml)") {
    set $cache_uri 'null cache';
}  

if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+
                     |wp-postpass|wordpress_logged_in|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_") {
    set $cache_uri 'null cache';
}
