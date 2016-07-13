DEB=/tmp/pandoc-1.17.1-2-amd64.deb
wget --no-clobber -O $DEB 'https://github.com/jgm/pandoc/releases/download/1.17.1/pandoc-1.17.1-2-amd64.deb'
ar p $DEB data.tar.gz | sudo tar xvz --strip-components 2 -C /usr/local
rm -f $DEB
