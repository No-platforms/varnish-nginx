#!/bin/bash

apt update
apt install docker docker.io docker-compose docker-compose-v2 varnish -y
cp ./varnish_config.vcl /etc/varnish/default.vcl
