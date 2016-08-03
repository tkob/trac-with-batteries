#!/bin/sh

die ()
{
  echo "$1"
  exit 1
}

lang=`python -c 'import locale; print(locale.getdefaultlocale()[0])'`
repo_type=svn
while getopts l:r: opt; do
  case $opt in #(
  l) :
    lang=$OPTARG ;; #(
  r) :
    repo_type=$OPTARG ;; #(
  *) :
     ;;
esac
done
shift `expr $OPTIND - 1`

test -z $1 && die "no project name specified"
PROJECT=$1

# Create a new site
(cd {{rb_parent}}; rb-site install --noinput --domain-name=localhost.localdomain --site-root=/reviews-$PROJECT/ --db-type=sqlite3 --db-name={{rb_parent}}/$PROJECT/data/reviewboard.db --admin-user=admin --admin-password=admin --admin-email=root@localhost.localdomain {{rb_parent}}/$PROJECT)

#  Let apache load the generated conf file
ln -s {{rb_parent}}/$PROJECT/conf/apache-wsgi.conf {{httpd_conf_parent}}/$PROJECT-rb.conf

#  Allow any hosts
perl -i -pne 's/ALLOWED_HOSTS\s*=.*/ALLOWED_HOSTS = ["*"]/' {{rb_parent}}/$PROJECT/conf/settings_local.py
(cd {{rb_parent}}; rb-site manage {{rb_parent}}/$PROJECT set-siteconfig -- --key auth_backend --value digest)
(cd {{rb_parent}}; rb-site manage {{rb_parent}}/$PROJECT set-siteconfig -- --key auth_digest_file_location --value {{httpd_conf_parent}}/$PROJECT/.htdigest)
(cd {{rb_parent}}; rb-site manage {{rb_parent}}/$PROJECT set-siteconfig -- --key auth_digest_realm --value Trac)

chown -R {{owner}}:{{group}} {{rb_parent}}/$PROJECT/htdocs/media/uploaded
chown -R {{owner}}:{{group}} {{rb_parent}}/$PROJECT/htdocs/media/ext
chown -R {{owner}}:{{group}} {{rb_parent}}/$PROJECT/htdocs/static/ext
chown -R {{owner}}:{{group}} {{rb_parent}}/$PROJECT/data

#  Restart HTTP server
service httpd restart

#  Setup repository
if test "X$repo_type" = "Xsvn"; then
  curl "http://localhost/reviews-${PROJECT}/api/repositories/" -H "Accept: application/json" -H "Authorization: Basic YWRtaW46YWRtaW4=" -X POST --data-urlencode "name=$PROJECT" --data-urlencode "path=file://{{svn_parent}}/$PROJECT" --data-urlencode "tool=Subversion"
fi
