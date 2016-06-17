#!/bin/sh

die ()
{
  echo "$1"
  exit 1
}

test -z $1 && die "no project name specified"
PROJECT=$1

rm -rf {{svn_parent}}/$PROJECT
rm -rf {{git_parent}}/$PROJECT
rm -rf {{trac_parent}}/$PROJECT
rm -rf {{httpd_conf_parent}}/$PROJECT
