#!/bin/sh

die ()
{
  echo "$1"
  exit 1
}

test -z $1 && die "no project name specified"
PROJECT=$1

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

svnadmin create {{svn_parent}}/$PROJECT
svn mkdir file:///{{svn_parent}}/$PROJECT/trunk file:///{{svn_parent}}/$PROJECT/tags file:///{{svn_parent}}/$PROJECT/branches -m "Initial commit"
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

mkdir -p {{trac_parent}}/$PROJECT
mkdir -p {{httpd_conf_parent}}/$PROJECT

trac-admin {{trac_parent}}/$PROJECT initenv "My Project" 'sqlite:db/trac.db'

echo 'admin:Trac:f208be21a9d1fc8328dac1ef375bf4a9' > {{httpd_conf_parent}}/$PROJECT/.htdigest

trac-admin {{trac_parent}}/$PROJECT permission add admin TRAC_ADMIN

trac-admin {{trac_parent}}/$PROJECT config set components tracopt.versioncontrol.git.* enabled
trac-admin {{trac_parent}}/$PROJECT config set components tracopt.ticket.commit_updater.* enabled
trac-admin {{trac_parent}}/$PROJECT config set components tracopt.ticket.clone.* enabled

# Subversion
trac-admin {{trac_parent}}/$PROJECT config set components tracopt.versioncontrol.svn.* enabled
trac-admin {{trac_parent}}/$PROJECT config set trac repository_type svn
trac-admin {{trac_parent}}/$PROJECT config set trac repository_dir {{svn_parent}}/$PROJECT
trac-admin {{trac_parent}}/$PROJECT config set trac repository_sync_per_request ""
trac-admin {{trac_parent}}/$PROJECT repository resync ""

# AccountManager
trac-admin {{trac_parent}}/$PROJECT config set components acct_mgr.* enabled
trac-admin {{trac_parent}}/$PROJECT config set components trac.web.auth disabled
trac-admin {{trac_parent}}/$PROJECT config set account-manager password_store HtDigestStore
trac-admin {{trac_parent}}/$PROJECT config set account-manager htdigest_realm Trac
trac-admin {{trac_parent}}/$PROJECT config set account-manager htdigest_file {{httpd_conf_parent}}/$PROJECT/.htdigest

# AutocompleteUsersPlugin
trac-admin {{trac_parent}}/$PROJECT config set components autocompleteusers.* enabled

# XML-RPC
trac-admin {{trac_parent}}/$PROJECT config set components tracrpc.* enabled
trac-admin {{trac_parent}}/$PROJECT permission add authenticated XML_RPC

# JupyterNotebook
trac-admin {{trac_parent}}/$PROJECT config set components tracjupyternotebook.* enabled

# BlockDiag
trac-admin {{trac_parent}}/$PROJECT config set components tracblockdiag.plugin.* enabled

# CustomFieldAdmin
trac-admin {{trac_parent}}/$PROJECT config set components customfieldadmin.* enabled

# Wysiwyg
trac-admin {{trac_parent}}/$PROJECT config set components tracwysiwyg.* enabled

# ExcelDownload
trac-admin {{trac_parent}}/$PROJECT config set components tracexceldownload.* enabled 

# ExportImportXls
trac-admin {{trac_parent}}/$PROJECT config set components importexportxls.admin_ui.* enabled

# DragDropPlugin
trac-admin {{trac_parent}}/$PROJECT config set components tracdragdrop.* enabled

# CiteCode
trac-admin {{trac_parent}}/$PROJECT config set components traccitecode.citecode.* enabled
