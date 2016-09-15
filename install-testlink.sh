#!/bin/sh

wget -O /tmp/testlink-1.9.15.tar.gz 'https://github.com/TestLinkOpenSourceTRMS/testlink-code/archive/1.9.15.tar.gz'
(cd /tmp; tar xzf testlink-1.9.15.tar.gz)
mv /tmp/testlink-1.9.15 /var/www/html/testlink
