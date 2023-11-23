#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

ruby_version="2.6.10"

nodejs_version="18"

# Workaround for Mastodon on Bullseye
# See https://github.com/mastodon/mastodon/issues/15751#issuecomment-873594463
if [ "$(lsb_release --codename --short)" = "bullseye" ]; then
    case $YNH_ARCH in
        amd64)
            arch="x86_64"
            ;;
        arm64)
            arch="aarch64"
            ;;
        armel|armhf)
            arch="arm"
            ;;
        i386)
            arch="i386"
            ;;
    esac
    ld_preload="LD_PRELOAD=/usr/lib/$arch-linux-gnu/libjemalloc.so"
else
    ld_preload=""
fi

#=================================================
# PERSONAL HELPERS
#=================================================

#=================================================
# EXPERIMENTAL HELPERS
#=================================================

#=================================================
# FUTURE OFFICIAL HELPERS
#=================================================
