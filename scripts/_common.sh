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

check_password_policy() {
    password="$1"
    # 12 caractères minimum, au moins une lettre majuscule, une lettre minuscule, un chiffre et un caractère spécial

    msg=""
    if (( ${#password} < 10 )); then
        msg="is too short"
    elif [[ $password != *[[:digit:]]* ]]; then
        msg="does not contain any digit"
    elif [[ $password != *[[:lower:]]* ]]; then
        msg="does not contain any lower case letter"
    elif [[ $password != *[[:upper:]]* ]]; then
        msg="does not contain any upper case letter"
    elif [[ "$password" =~ ^[0-9a-zA-Z]*$ ]]; then
        msg="does not contain any special character"
    fi

    if [ -n "$msg" ]; then
        ynh_die "Password should have min 12 chars, at least one lowercase, one uppercase, one digit and one special character, but it $msg."
    fi
}

env_ruby() {
    ynh_exec_as "$app" "$ynh_ruby_load_path" "$@"
}


fabmanager_build_ruby() {
    pushd "$install_dir"
        ynh_use_ruby
        $ynh_gem update --system --no-document
        $ynh_gem install bundler rake --no-document

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
        env_ruby bash -c "set -a; source '$install_dir/.env'; set +a ; RAILS_ENV=production bin/bundle exec rake assets:precompile"
        ynh_exec_warn_less ynh_exec_as "$app" env "$ynh_node_load_PATH" yarn cache clean --all
    popd
}

fabmanager_seed_db() {
    pushd "$install_dir"
        ynh_replace_string --match_string="DateTime.current" --replace_string="DateTime.current - 1.days" --target_file="$install_dir/db/seeds.rb"
        # Need superuser for the extensions configuration…
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH SUPERUSER;"
        env_ruby bash -c "set -a; source '$install_dir/.env'; set +a ; RAILS_ENV=production ADMIN_EMAIL='$admin_mail' ADMIN_PASSWORD='$password' bin/bundle exec rails db:schema:load"
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH NOSUPERUSER;"
        env_ruby bash -c "set -a; source '$install_dir/.env'; set +a ; RAILS_ENV=production ADMIN_EMAIL='$admin_mail' ADMIN_PASSWORD='$password' bin/bundle exec rails db:seed"
    popd
}

fabmanager_migrate_db() {
    pushd "$install_dir"
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH SUPERUSER;"
        env_ruby bash -c "set -a; source '$install_dir/.env'; set +a ; RAILS_ENV=production bin/bundle exec rails db:migrate"
        ynh_psql_execute_as_root --database="$db_name" --sql="ALTER USER $db_user WITH NOSUPERUSER;"
    popd
}


#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
