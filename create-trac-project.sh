#!/bin/sh

die ()
{
  echo "$1"
  exit 1
}

github=
lang=`python -c 'import locale; print(locale.getdefaultlocale()[0])'`
repo_type=svn
while getopts g:l:r: opt; do
  case $opt in #(
  g) :
    github=$OPTARG ;; #(
  l) :
    lang=$OPTARG ;; #(
  r) :
    repo_type=$OPTARG ;; #(
  *) :
     ;;
esac
done
shift `expr $OPTIND - 1`

if test "X$repo_type" = "Xgithub"; then
  test -z $github && die "no github repo specified"
fi

test -z $1 && die "no project name specified"
PROJECT=$1

if test "X$repo_type" = "Xgit"; then
  mkdir -p {{git_parent}}/$PROJECT
  (cd {{git_parent}}/$PROJECT; git init --bare --shared)
  (cd {{git_parent}}/$PROJECT; git update-server-info)

  cat <<EOF > {{git_parent}}/$PROJECT/hooks/post-receive
#!/usr/bin/env python
import sys
from subprocess import Popen, PIPE, call

BRANCHES = ['master']
REPO_NAME = '(default)'

def call_git(command, args):
    return Popen(['/usr/bin/git', command] + args, stdout=PIPE).communicate()[0]

def handle_ref(old, new, ref):
    # If something else than the master branch (or whatever is contained by the
    # constant BRANCHES) was pushed, skip this ref.
    if not ref.startswith('refs/heads/') or ref[11:] not in BRANCHES:
        return

    # Get the list of hashs for commits in the changeset.
    args = (old == '0' * 40) and [new] or [new, '^' + old]
    pending_commits = call_git('rev-list', args).splitlines()[::-1]

    call(["trac-admin", '{{trac_parent}}/$PROJECT', "changeset", "added", REPO_NAME] + pending_commits)

if __name__ == '__main__':
    for line in sys.stdin:
        handle_ref(*line.split())
EOF
  chmod 755 {{git_parent}}/$PROJECT/hooks/post-receive
fi

if test "X$repo_type" = "Xgithub"; then
  mkdir -p {{git_parent}}/$PROJECT
  (cd {{git_parent}}; git clone --mirror "https://github.com/${github}.git" $PROJECT)
  (cd {{git_parent}}/$PROJECT; git update-server-info)
fi

if test "X$repo_type" = "Xsvn"; then
  svnadmin create {{svn_parent}}/$PROJECT
  svn mkdir \
          file:///{{svn_parent}}/$PROJECT/trunk \
          file:///{{svn_parent}}/$PROJECT/tags \
          file:///{{svn_parent}}/$PROJECT/branches \
          -m "Initial commit" \
          --username admin
  cat <<EOF > {{httpd_conf_parent}}/$PROJECT.conf
<Location /svn/$PROJECT>
  DAV svn
  SVNPath {{svn_parent}}/$PROJECT
  SVNAdvertiseV2Protocol Off

  AuthType Digest
  AuthName "Trac"
  AuthUserFile {{httpd_conf_parent}}/$PROJECT/.htdigest
  Require valid-user
</Location>

<LocationMatch "/trac/$PROJECT/login/(xmlrpc|rpc|jsonrpc)($|/)">
  AuthType Digest
  AuthName "Trac"
  AuthUserFile {{httpd_conf_parent}}/$PROJECT/.htdigest
  Require valid-user
</LocationMatch>

<Location /git/$PROJECT>
  AuthType Digest
  AuthName "Trac"
  AuthUserFile {{httpd_conf_parent}}/$PROJECT/.htdigest
  Require valid-user
  Order allow,deny
  Allow from all
</Location>
EOF

cat <<EOF > {{svn_parent}}/$PROJECT/hooks/post-commit
#!/bin/sh
REPOS="\$1"; REV="\$2"
/usr/bin/trac-admin {{trac_parent}}/$PROJECT changeset added "\$REPOS" "\$REV"
EOF
  chmod 755 {{svn_parent}}/$PROJECT/hooks/post-commit

  cat <<EOF > {{svn_parent}}/$PROJECT/hooks/post-revprop-change
#!/bin/sh
REPOS="\$1"; REV="\$2"
/usr/bin/trac-admin {{trac_parent}}/$PROJECT changeset modified "\$REPOS" "\$REV"
EOF
  chmod 755 {{svn_parent}}/$PROJECT/hooks/post-revprop-change
fi

mkdir -p {{trac_parent}}/$PROJECT
mkdir -p {{httpd_conf_parent}}/$PROJECT

trac-admin {{trac_parent}}/$PROJECT initenv "$PROJECT" 'sqlite:db/trac.db'

if test -d {{var_root}}/wiki/$lang/default-pages; then
  trac-admin {{trac_parent}}/$PROJECT wiki replace {{var_root}}/wiki/$lang/default-pages
fi

echo 'admin:Trac:f208be21a9d1fc8328dac1ef375bf4a9' > {{httpd_conf_parent}}/$PROJECT/.htdigest

trac-admin {{trac_parent}}/$PROJECT permission add admin TRAC_ADMIN

config_append ()
{
  section=$1
  key=$2
  value=$3
  old="`trac-admin {{trac_parent}}/$PROJECT config get $section $key`"
  trac-admin {{trac_parent}}/$PROJECT config set $section $key "$old, $value"
}

trac-admin {{trac_parent}}/$PROJECT config set header_logo src common/trac_banner.png

trac-admin {{trac_parent}}/$PROJECT config set components tracopt.ticket.commit_updater.* enabled
trac-admin {{trac_parent}}/$PROJECT config set components tracopt.ticket.clone.* enabled

# Git
if test "X$repo_type" = "Xgit"; then
  trac-admin {{trac_parent}}/$PROJECT config set components tracopt.versioncontrol.git.* enabled
  trac-admin {{trac_parent}}/$PROJECT repository add "" {{git_parent}}/$PROJECT git
  trac-admin {{trac_parent}}/$PROJECT repository resync ""
fi

# GitHub
if test "X$repo_type" = "Xgithub"; then
  trac-admin {{trac_parent}}/$PROJECT config set components tracext.github.* enabled
  trac-admin {{trac_parent}}/$PROJECT config set components tracopt.versioncontrol.git.* enabled
  trac-admin {{trac_parent}}/$PROJECT config set components tracopt.ticket.commit_updater.* enabled
  trac-admin {{trac_parent}}/$PROJECT config set components trac.versioncontrol.web_ui.browser.BrowserModule disabled
  trac-admin {{trac_parent}}/$PROJECT config set components trac.versioncontrol.web_ui.changeset.ChangesetModule disabled
  trac-admin {{trac_parent}}/$PROJECT config set components trac.versioncontrol.web_ui.log.LogModule disabled
  trac-admin {{trac_parent}}/$PROJECT config set components tracext.github.GitHubBrowser enabled
  trac-admin {{trac_parent}}/$PROJECT config set github repository $github
  trac-admin {{trac_parent}}/$PROJECT repository add "" {{git_parent}}/$PROJECT git
  trac-admin {{trac_parent}}/$PROJECT repository resync ""
fi

# Subversion
if test "X$repo_type" = "Xsvn"; then
  trac-admin {{trac_parent}}/$PROJECT config set components tracopt.versioncontrol.svn.* enabled
  trac-admin {{trac_parent}}/$PROJECT repository add "" {{svn_parent}}/$PROJECT svn
  trac-admin {{trac_parent}}/$PROJECT repository resync ""
fi

# Enable additional plugins

# AccountManager
trac-admin {{trac_parent}}/$PROJECT config set components acct_mgr.* enabled
trac-admin {{trac_parent}}/$PROJECT config set components trac.web.auth disabled
trac-admin {{trac_parent}}/$PROJECT config set account-manager password_store HtDigestStore
trac-admin {{trac_parent}}/$PROJECT config set account-manager htdigest_realm Trac
trac-admin {{trac_parent}}/$PROJECT config set account-manager htdigest_file {{httpd_conf_parent}}/$PROJECT/.htdigest

# AsciidoctorPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracasciidoctor.* enabled
config_append mimeviewer mime_map "text/asciidoc:adoc:asc:asciidoc"

# AutocompleteUsersPlugin
trac-admin {{trac_parent}}/$PROJECT config set components autocompleteusers.* enabled

# BlockDiag
trac-admin {{trac_parent}}/$PROJECT config set components tracblockdiag.plugin.* enabled

# CiteCode
trac-admin {{trac_parent}}/$PROJECT config set components traccitecode.citecode.* enabled

# CustomFieldAdmin
trac-admin {{trac_parent}}/$PROJECT config set components customfieldadmin.* enabled

# DragDropPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracdragdrop.* enabled

# ExcelDownload
trac-admin {{trac_parent}}/$PROJECT config set components tracexceldownload.* enabled 

# ExportImportXls
trac-admin {{trac_parent}}/$PROJECT config set components importexportxls.admin_ui.* enabled

# IniAdminPanel
trac-admin {{trac_parent}}/$PROJECT config set components inieditorpanel.* enabled

# JupyterNotebook
trac-admin {{trac_parent}}/$PROJECT config set components tracjupyternotebook.* enabled
config_append mimeviewer mime_map "application/x-ipynb+json:ipynb"

# LDAPAcctMngrPlugin
trac-admin {{trac_parent}}/$PROJECT config set components security.ldapstore.* enabled

# LogViewer
trac-admin {{trac_parent}}/$PROJECT config set components logviewer.* enabled

# Mermaid
trac-admin {{trac_parent}}/$PROJECT config set components tracmermaid.mermaid.* enabled

# PandocPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracpandoc.* enabled
config_append mimeviewer mime_map "application/vnd.openxmlformats-officedocument.wordprocessingml.document:docx"

# PdfPreviewPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracpdfpreview.* enabled
config_append mimeviewer mime_map "application/pdf:pdf"

# PerlPodPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracperlpod.* enabled
config_append mimeviewer mime_map "application/x-perlpod:pod"

# ReadmeRenderer
trac-admin {{trac_parent}}/$PROJECT config set components readme_renderer.* enabled
config_append mimeviewer mime_map "text/x-trac-wiki:wiki"
config_append mimeviewer mime_map "text/x-markdown:md"
config_append mimeviewer mime_map_patterns "text/plain:README:INSTALL:COPYING"

# SubcomponentsPlugin
trac-admin {{trac_parent}}/$PROJECT config set components subcomponents.* enabled

# SvnMultiUrlsPlugin
if test "X$repo_type" = "Xsvn"; then
  trac-admin {{trac_parent}}/$PROJECT config set components svnmultiurls.* enabled
  trac-admin {{trac_parent}}/$PROJECT config set svnmultiurls repository_root_url /svn/$PROJECT
fi

# TicketStencilPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracticketstencil.* enabled

# WikiGanttChartPlugin
trac-admin {{trac_parent}}/$PROJECT config set components wikiganttchart.* enabled

# Wysiwyg
trac-admin {{trac_parent}}/$PROJECT config set components tracwysiwyg.* enabled

# XML-RPC
trac-admin {{trac_parent}}/$PROJECT config set components tracrpc.* enabled
trac-admin {{trac_parent}}/$PROJECT permission add authenticated XML_RPC
