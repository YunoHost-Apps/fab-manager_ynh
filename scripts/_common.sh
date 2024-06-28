#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

ruby_version="3.2.2"
bundler_version=2.1.4
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

fabmanager_build_ruby() {
    pushd "$install_dir"
        ynh_use_ruby
        ynh_exec_warn_less ynh_exec_as "$app" $ynh_gem install "bundler:$bundler_version"
        ynh_exec_warn_less ynh_exec_as "$app" bin/bundle config --global frozen 1
        ynh_exec_warn_less ynh_exec_as "$app" bin/bundle config set --local without 'development test doc'
        ynh_exec_warn_less ynh_exec_as "$app" bin/bundle install
        ynh_exec_warn_less ynh_exec_as "$app" bin/bundle binstubs --all
    popd
}

fabmanager_build_ui() {
    pushd "$install_dir"
        ynh_use_nodejs
        ynh_exec_warn_less ynh_exec_as "$app" env "$ynh_node_load_PATH" yarn install
        #ynh_exec_warn_less ynh_exec_as "$app" env RAILS_ENV=production "$ynh_ruby_load_path" $ld_preload yarn install
        #ynh_exec_warn_less ynh_exec_as "$app" env RAILS_ENV=production "$ynh_ruby_load_path" $ld_preload bin/webpack
        ynh_exec_warn_less ynh_exec_as "$app" env RAILS_ENV=production "$ynh_ruby_load_path" $ld_preload bin/bundle exec rails assets:precompile
        ynh_exec_warn_less ynh_exec_as "$app" env "$ynh_node_load_PATH" yarn cache clean --all
    popd
}

fabmanager_seed_db() {
    pushd "$install_dir"
        ynh_replace_string --match_string="DateTime.current" --replace_string="DateTime.current - 1.days" --target_file="$install_dir/db/seeds.rb"
        ynh_exec_warn_less ynh_exec_as "$app" env RAILS_ENV=production "$ynh_ruby_load_path" $ld_preload \
            bin/bundle exec rails db:seed ADMIN_EMAIL="$admin_mail" ADMIN_PASSWORD="$password"
    popd
}

fabmanager_migrate_db() {
    pushd "$install_dir"
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH SUPERUSER;"
        ynh_exec_warn_less ynh_exec_as "$app" env RAILS_ENV=production "$ynh_ruby_load_path" $ld_preload bin/bundle exec rails db:migrate
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH NOSUPERUSER;"
    popd
}


#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
