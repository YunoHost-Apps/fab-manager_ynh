#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

ruby_version="2.6.10"
bundler_version=2.1.4

nodejs_version="14"

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

fabmanager_build_ruby() {
    pushd "$install_dir"

        ynh_hide_warnings gem install "bundler:$bundler_version"
        ynh_hide_warnings bin/bundle config --global frozen 1
        ynh_hide_warnings bin/bundle config set --local without 'development test doc'
        ynh_hide_warnings bin/bundle install
        ynh_hide_warnings bin/bundle binstubs --all
    popd
}

fabmanager_seed_db() {
    pushd "$install_dir"
        ynh_replace --match="DateTime.current" --replace="DateTime.current - 1.days" --file="$install_dir/db/seeds.rb"
        ynh_hide_warnings ynh_exec_as_app RAILS_ENV=production ruby_load_path" $ld_preload \
            bin/bundle exec rake db:seed ADMIN_EMAIL="$admin_mail" ADMIN_PASSWORD="$password"
    popd
}

fabmanager_migrate_db() {
    pushd "$install_dir"
        ynh_psql_db_shell  <<< "ALTER USER $db_user WITH SUPERUSER;"
        ynh_hide_warnings ynh_exec_as_app RAILS_ENV=production ruby_load_path" $ld_preload bin/bundle exec rake db:migrate
        ynh_psql_db_shell  <<< "ALTER USER $db_user WITH NOSUPERUSER;"
    popd
}

fabmanager_build_ui() {
    pushd "$install_dir"

        ynh_hide_warnings ynh_exec_as_app node_load_PATH" yarn install
        #ynh_hide_warnings ynh_exec_as_app RAILS_ENV=production ruby_load_path" $ld_preload yarn install
        #ynh_hide_warnings ynh_exec_as_app RAILS_ENV=production ruby_load_path" $ld_preload bin/webpack
        ynh_hide_warnings ynh_exec_as_app RAILS_ENV=production ruby_load_path" $ld_preload bin/bundle exec rake assets:precompile
        ynh_hide_warnings ynh_exec_as_app node_load_PATH" yarn cache clean --all
    popd
}
