#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

ruby_version="3.2.2"
nodejs_version="18"

# Workaround for Mastodon on Bullseye
# See https://github.com/mastodon/mastodon/issues/15751#issuecomment-873594463
if [ "$(lsb_release --codename --short)" = "bullseye" ]; then
    case $YNH_ARCH in
        amd64) arch="x86_64";;
        arm64) arch="aarch64";;
        armel|armhf) arch="arm";;
        i386) arch="i386";;
    esac
    ld_preload="LD_PRELOAD=/usr/lib/$arch-linux-gnu/libjemalloc.so"
else
    ld_preload=""
fi

#=================================================
# PERSONAL HELPERS
#=================================================

env_ruby() {
    ynh_exec_as "$app" "$ynh_ruby_load_path" env RAILS_ENV=production  "$@"
}


fabmanager_build_ruby() {
    pushd "$install_dir"
        ynh_use_ruby
        ynh_gem update --system --no-document
        ynh_gem install bundler rake --no-document

        env_ruby bin/bundle config --global frozen 1
        env_ruby bin/bundle config set without 'development test doc'
        env_ruby bin/bundle config set path 'vendor/bundle'
        env_ruby bin/bundle install
        env_ruby bin/bundle binstubs --all

    popd
}

fabmanager_build_ui() {
    pushd "$install_dir"
        ynh_use_nodejs
        ynh_exec_warn_less ynh_exec_as "$app" env "$ynh_node_load_PATH" yarn install
        #env_ruby yarn install
        #env_ruby bin/webpack
        env_ruby bin/bundle exec rails assets:precompile
        ynh_exec_warn_less ynh_exec_as "$app" env "$ynh_node_load_PATH" yarn cache clean --all
    popd
}

fabmanager_seed_db() {
    pushd "$install_dir"
        ynh_replace_string --match_string="DateTime.current" --replace_string="DateTime.current - 1.days" --target_file="$install_dir/db/seeds.rb"
        env_ruby bin/bundle exec rails db:seed ADMIN_EMAIL="$admin_mail" ADMIN_PASSWORD="$password"
    popd
}

fabmanager_migrate_db() {
    pushd "$install_dir"
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH SUPERUSER;"
        env_ruby bin/bundle exec rails db:migrate
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH NOSUPERUSER;"
    popd
}


#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
