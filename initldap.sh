#!/bin/sh

ldapadd -x -D "cn=Manager,dc=my-domain,dc=com" -w secret -f /usr/local/share/applications/init.ldif
