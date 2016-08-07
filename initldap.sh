#!/bin/sh

ldapadd -Y EXTERNAL -H ldapi:// -f /usr/local/share/applications/olcRootPW.ldif
ldapadd -x -D "cn=Manager,dc=my-domain,dc=com" -w secret -f /usr/local/share/applications/init.ldif
