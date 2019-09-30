#!/bin/bash
apt-get -y install libgtk-3-0 libx11-xcb1 libdbus-glib-1-2 libxt6
curl -o ffnightly.tar.bz2 https://download-installer.cdn.mozilla.net/pub/firefox/nightly/latest-mozilla-central/firefox-71.0a1.en-US.linux-x86_64.tar.bz2
tar -xvjf ffnightly.tar.bz2
mv firefox/ /opt/
chown vagrant:vagrant /opt/firefox