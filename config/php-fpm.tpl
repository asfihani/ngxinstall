[%%domainname%%]
user = %%username%%
group = %%username%%
listen = /run/%%domainname%%-fpm.sock
listen.owner = nginx
listen.group = nginx
pm = ondemand
pm.process_idle_timeout = 30s
pm.max_requests = 512
pm.max_children = 30

php_admin_flag[allow_url_fopen] = on
php_admin_flag[log_errors] = on
php_admin_value[disable_functions] = dl,passthru,proc_open,proc_close,shell_exec,system,exec,show_source,popen,allow_url_fopen
php_admin_value[doc_root] = "/chroot/%%username%%/home/%%username%%/public_html"
php_admin_value[error_log] = /chroot/%%username%%/home/%%username%%/logs/%%domainname%%.php.error.log
php_admin_value[short_open_tag] = on
php_value[error_reporting] = E_ALL & ~E_NOTICE
