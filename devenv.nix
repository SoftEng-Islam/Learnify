{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.WORDPRESS_VERSION = "6.8";
  env.WORDPRESS_REPO = "https://github.com/WordPress/WordPress";
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.wp-cli pkgs.caddy ];

  services.caddy = {
    enable = false;
    config = ''
      :2015 {
        handle_path / {
          reverse_proxy localhost:8080
        }
      }
    '';
  };

  # https://devenv.sh/languages/
  # Configure PHP
  languages.php.package = pkgs.php83.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [ yaml ]));
    extraConfig = ''
      sendmail_path = ${config.services.mailpit.package}/bin/mailpit sendmail
      smtp_port = 1025
    '';
  };
  languages.php.fpm.pools.web = {
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 10;
      "access.log" = "/tmp/php-fpm.access.log";
      "slowlog" = "/tmp/php-fpm.slow.log";
      "request_slowlog_timeout" = "5s";
      "catch_workers_output" = "yes";
    };
  };
  languages.php.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # MySQL
  services.mysql = {
    enable = true;
    settings.mysqld.port = 3307;
    initialDatabases = [{ name = "wordpress"; }];
    ensureUsers = [{
      name = "wordpress";
      password = "wordpress";
      ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
    }];
  };

  # NGINX
  services.nginx = {
    enable = true;
    httpConfig = ''
      types_hash_max_size 2048;
      types_hash_bucket_size 128;
      server {
        listen 8080;
        root ${config.devenv.root}/html;
        index index.php index.html;
        server_name localhost;

        # Rewrite rules
        if (!-e $request_filename) {
          rewrite /wp-admin$ $scheme://$host$request_uri/ permanent;
          rewrite ^(/[^/]+)?(/wp-.*) $2 last;
          rewrite ^(/[^/]+)?(/.*\.php) $2 last;
        }

        location ~ \.php$ {
          try_files $uri =404;
          fastcgi_pass unix:${config.languages.php.fpm.pools.web.socket};
          include ${pkgs.nginx}/conf/fastcgi.conf;
        }
    '' + (builtins.readFile ./conf/nginx/locations) + "}";
  };

  # Mailpit
  services.mailpit = { enable = true; };

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  # Sets up local WordPress core
  enterShell = ''
    # sudo setcap 'cap_net_bind_service=+ep' ${pkgs.nginx}/bin/nginx
    test -d html || git clone --depth 1 --branch ${config.env.WORDPRESS_VERSION} ${config.env.WORDPRESS_REPO} html
    composer install
    php --version
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
