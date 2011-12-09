# Author: Kumina bv <support@kumina.nl>

# Class: gen_glassfish
#
# Actions:
#  Install glassfish package and java
#
# Depends:
#  gen_puppet
#
class gen_glassfish {
  include gen_java::sun_java6_jdk

  kpackage { "glassfish":
    require => Package['sun-java6-jdk'];
  }
}

# Define: gen_glassfish::domain
#
# Actions:
#  Creates a glassfish domain and sets some options
#
# Parameters:
#  portbase
#   The portbase value determines where the port assignment should start. The values for the ports are calculated as follows:
#   Administration port: portbase + 48
#   HTTP listener port: portbase + 80
#   HTTPS listener port: portbase + 81
#   JMS port: portbase + 76
#   IIOP listener port: portbase + 37
#   Secure IIOP listener port: portbase + 38
#   Secure IIOP with mutual authentication port: portbase + 39
#   JMX port: portbase + 86
#   JPDA debugger port: portbase + 9
#   Felix shell service port for OSGi module management: portbase + 66
#
#  ensure
#   What the domain should be, needed for the service.. should be running or stopped
#   There is some discussion as to what absent should do (because the domain could be on a shared storage medium).
#
#  autostart
#   Should this domain be started when the system boots (make it true when ensure is running)
#
# Depends:
#  gen_puppet
#  gen_glassfish
#
define gen_glassfish::domain ($portbase, $ensure='running'){

  exec { "Create glassfish domain ${name}":
    command => "/opt/glassfish/bin/asadmin create-domain --nopassword=true --portbase ${portbase} ${name} ",
    creates => "/opt/glassfish/domains/${name}",
    user    => 'glassfish',
    group   => 'glassfish',
    require => Package['glassfish'];
  }

  kfile { "/etc/init.d/glassfish-${name}":
    ensure  => present,
    mode    => 755,
    content => template('gen_glassfish/init'),
    require => Exec["Create glassfish domain ${name}"];
  }

  service { "glassfish-${name}":
    ensure  => $ensure,
    require => File["/etc/init.d/glassfish-${name}"];
  }
}