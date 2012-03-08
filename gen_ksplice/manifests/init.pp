# Author: Kumina bv <support@kumina.nl>

# Copyright (C) 2010 Kumina bv, Tim Stoop <tim@kumina.nl>
# This works is published under the Creative Commons Attribution-Share
# Alike 3.0 Unported license - http://creativecommons.org/licenses/by-sa/3.0/
# See LICENSE for the full legal text.

# Class: gen_ksplice
#
# Actions:
#  Undocumented
#
# Depends:
#  gen_apt::source
#  gen_apt::key
#  gen_puppet
#
class ksplice {
  # Add the source repo
  gen_apt::source { "ksplice":
    uri          => "http://www.ksplice.com/apt",
    distribution => "${lsbdistcodename}",
    components   => ["ksplice"],
  }

  # Preseed the ksplice package
  kfile { "/var/cache/debconf/ksplice.preseed":
    content => template("ksplice/ksplice.preseed");
  }

  # Install the ksplice package
  kpackage { "uptrack":
    ensure       => latest,
    responsefile => "/var/cache/debconf/ksplice.preseed",
    require      => [File["/var/cache/debconf/ksplice.preseed"],Gen_apt::Source["ksplice"]],
    notify       => Exec["initial uptrack run"];
  }

  # Install the ksplice additional apps (includes nagios plugins)
  kpackage { "python-ksplice-uptrack":
    require => Gen_apt::Source["ksplice"],
    ensure  => latest,
  }

  # Run the script when it's first installed
  exec { "initial uptrack run":
    command     => "/usr/sbin/uptrack-upgrade -y; exit 0",
    refreshonly => true,
    require     => File["/etc/uptrack/uptrack.conf"],
  }

  # The modified configuration file
  kfile { "/etc/uptrack/uptrack.conf":
    content => template("ksplice/uptrack.conf"),
    require => Package["uptrack"],
  }

  # Set directory permissions so Nagios can read status
  kfile { "/var/cache/uptrack":
    require => Package["uptrack"];
  }
}
