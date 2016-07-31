#!/bin/sh

die ()
{
  echo "$1"
  exit 1
}

test -z $1 && die "no project name specified"
PROJECT=$1

rm -rf {{httpd_conf_parent}}/$PROJECT-rb.conf
rm -rf {{rb_parent}}/$PROJECT
