# Author: Kumina bv <support@kumina.nl>

# Class: gen_git
#
# Actions:
#  Install git
#
# Depends:
#  gen_puppet
#
class gen_git {
  if $lsbdistcodename != 'lenny' {
    $git_pkg = "git"
  } else { #lenny or older
    $git_pkg = "git-core"
  }

  package {
    "${git_pkg}":
      alias  => "git",
      ensure => latest;
    "tig":
      ensure => latest;
  }
}

# Class: gen_git::listchanges
#
# Actions:
#  Install gitlistchanges
#
# Depends:
#  gen_puppet
#
class gen_git::listchanges::install {
  package { "gitlistchanges":
    ensure => latest;
  }

  file {
    "/etc/gitlistchanges.conf":
      content => "includedir:/etc/gitlistchanges.conf.d\n";
    "/etc/gitlistchanges.conf.d":
      ensure  => directory,
      purge   => true,
      recurse => true;
  }
}

# Define: gen_git::repo
#
# Actions:
#  Set up git repository
#
# Parameters:
#  name
#    The directory where to create the repository.
#    Needs to be a kfile already. Unless it's bare,
#  branch
#    The remote branch of the origin. Defaults to
#    "master".
#  origin
#    Add an origin to the repository. This does
#    not clone the remote repository.
#  bare
#    Should this repository be a bare repository?
#
# Depends:
#  gen_git
#  gen_puppet
#
define gen_git::repo ($branch = "master", $origin = false, $bare = false, $post_update_content = template("gen_git/post-update")) {
  include gen_git

  # I thought about adding an option to automatically clone a remote
  # repository, but that won't work very often since you'd have to
  # give puppet access to your ssh secret key. You don't want that.

  if !$bare {
    exec {
      "/usr/bin/git init -q --shared=group ${name}":
        creates => "${name}/.git",
        require => [Package["git"]];
      "/usr/bin/git config --add receive.denyCurrentBranch ignore on ${name}":
        command => "/usr/bin/git config --add receive.denyCurrentBranch ignore",
        cwd     => $name,
        unless  => "/usr/bin/git config --get receive.denyCurrentBranch | grep -q 'ignore'",
        require => Exec["/usr/bin/git init -q --shared=group ${name}"];
    }
    # This is the hook that makes sure we always have the latest version checked out.
    file { "${name}/.git/hooks/post-update":
      content => $post_update_content,
      mode    => 755,
      require => Exec["/usr/bin/git init -q --shared=group ${name}"];
    }
  } else {
    exec { "/usr/bin/git init --bare -q --shared=group ${name}":
      creates => "${name}",
      require => Package["git"];
    }
    # Install a post-update hook if we supply the content
    if $post_update_content {
      file { "${name}/hooks/post-update":
        content => $post_update_content,
        mode    => 755,
        require => Exec["/usr/bin/git init --bare -q --shared=group ${name}"];
      }
    }
  }

  if $origin {
    exec {
      "/usr/bin/git remote add -m ${branch} origin ${origin}":
        cwd     => $name,
        unless  => "/usr/bin/git config --get remote.origin.url | grep -q '${origin}'",
        require => Exec["/usr/bin/git init -q --shared=group ${name}"];
      "/usr/bin/git config --add branch.master.remote origin on ${name}":
        command => "/usr/bin/git config --add branch.master.remote origin",
        cwd     => $name,
        unless  => "/usr/bin/git config --get branch.master.remote | grep -q 'origin'",
        require => Exec["/usr/bin/git init -q --shared=group ${name}"];
      "/usr/bin/git config --add branch.master.merge refs/heads/master on ${name}":
        command => "/usr/bin/git config --add branch.master.merge refs/heads/master",
        cwd     => $name,
        unless  => "/usr/bin/git config --get branch.master.merge | grep -q 'refs/heads/master'",
        require => Exec["/usr/bin/git init -q --shared=group ${name}"];
      "/usr/bin/git config --add branch.master.rebase true on ${name}":
        command => "/usr/bin/git config --add branch.master.rebase true",
        cwd     => $name,
        unless  => "/usr/bin/git config --get branch.master.rebase | grep -q 'true'",
        require => Exec["/usr/bin/git init -q --shared=group ${name}"];
    }
  }
}

# Define: gen_git::listchanges
#
# Actions:
#  Set up config for gitlistchanges
#
# Parameters:
#  to
#    Mail address the changes will be mailed to
#  repo
#    Path to the repo, defaults to the name
#  from
#    Sender address, not set by default
#  branch
#    Branch to report on, not set by default
#  since
#    Report from this moment till now, not set by default
#  condense
#    Leave out committer names and detailed info, not set by default
#
# Depends:
#  gen_git::listchanges::install
#  gen_puppet
#
define gen_git::listchanges ($to, $repo=false, $from=false, $branch=false, $since=false, $condense=false) {
  include gen_git::listchanges::install

  $the_repo = $name ? {
    false   => $repo,
    default => $name,
  }
  $the_repo_safe = regsubst($the_repo, '/', '_', "G")

  file { "/etc/gitlistchanges.conf.d/${the_repo_safe}-${to}":
    content => template("gen_git/listchanges/repoconfig.erb");
  }
}
