# Copyright (c) 2005
#	The funknet.org Group.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#	This product includes software developed by The funknet.org
#	Group and its contributors.
# 4. Neither the name of the Group nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE GROUP AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE GROUP OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.


package Funknet::Config::Tunnel::OpenVPN;
use strict;
use base qw/ Funknet::Config::Tunnel /;
use Funknet::Config::Util qw/ dq_to_int /;
use Funknet::Config::SystemFile;
use Funknet::Debug;

=head1 NAME

Funknet::Config::Tunnel::OpenVPN

=head1 DESCRIPTION

This class contains methods for parsing, creating and deleting tunnel
interfaces on OpenVPN.

=head1 METHODS

=head2 config

Returns the configuration of the Tunnel object as text. This should be
in roughly the format used by the host. TODO: make this be
so. Currently we just dump the information in an arbitrary format.

=head2 new_from_ifconfig

Reads a host interface description taken from ifconfig and parses the
useful information from it. Only 'tun' and 'tap' interfaces are
supported for OpenVPN; other interface types cause this method to return
undef.

=head2 create

Returns a list of strings containing commands to configure a tunnel
interface with OpenVPN. The interface details are passed in as part of
$self, and the new interface number is passed in as $inter. The
commands should assume that no interface with that number currently
exists.

=head2 delete

Returns a list of strings containing commands to unconfigure an OpenVPN
tunnel interface. The interface should be removed, not just put into
the 'down' state. 

=cut

sub config {
    my ($self) = @_;

    return 
	"OpenVPN\n" .
	"$self->{_type}:\n" .
	"$self->{_local_endpoint} -> $self->{_remote_endpoint}\n" . 
	"$self->{_local_address} -> $self->{_remote_address}\n";
}

sub host_tunnels {
    my ($class) = @_;
    my @local_tun;
    
    my $l = Funknet::ConfigFile::Tools->encryption;
    my $openvpn_conf_dir = $l->{openvpn_conf_dir};

    opendir CONF, $openvpn_conf_dir
      or die "can't open ".($openvpn_conf_dir).": $!";
    for my $filename (readdir CONF) {

	next unless $filename =~ /\.conf$/;
	$filename = $openvpn_conf_dir . '/' . $filename;

	debug("reading $filename");

	my $tun = Funknet::Config::Tunnel::OpenVPN->new_from_ovpn_conf( $filename );
	if (defined $tun) {
	    push @local_tun, $tun;
	}
    }
    closedir CONF;
    return @local_tun;
}

sub new_from_ovpn_conf {
    my ($class, $filename) = @_;

    open CONF, $filename or die "can't open $filename: $!";
    my $text;
    {
	local $/ = undef;
	$text = <CONF>;
    }
    close CONF;

    my $conf = _parse_openvpn_conf($text);
    my ($local_address, $remote_address) = $conf->{ifconfig} =~ /(.*) (.*)/;
    my ($iftype, $ifnum) = $conf->{dev} =~ /^([a-z]+)(\d+)$/;

    my ($local_endpoint, $remote_endpoint);
    if (exists $conf->{'tls-server'}) {
	$local_endpoint  = $conf->{local};
	$remote_endpoint = $conf->{fn_remote_endpoint};
    } elsif (exists $conf->{'tls-client'}) {
	$remote_endpoint = $conf->{remote};
	$local_endpoint  = $conf->{fn_local_endpoint};
    } else {
	# not sure what good this does us.
	$remote_endpoint = $conf->{fn_remote_endpoint};
	$local_endpoint  = $conf->{fn_local_endpoint};
    }

    my $tunnel = Funknet::Config::Tunnel->new(
					      local_address   => $local_address,
					      remote_address  => $remote_address,
					      local_endpoint  => $local_endpoint,
					      remote_endpoint => $remote_endpoint,
					      interface       => $ifnum,
					      type            => $iftype,
					      ifname          => $conf->{dev},
					      source          => 'host',
					      proto           => '4',
					     );

    # stash some extra bits in here that various things need
    $tunnel->{_ovpn_port}    = $conf->{port};
    $tunnel->{_ovpn_file}    = $filename;
    $tunnel->{_ovpn_pidfile} = $conf->{writepid};
    if (exists $conf->{'tls-server'}) {
         $tunnel->{_ovpn_server} = 1;
    }
    if (exists $conf->{'tls-client'}) {
         $tunnel->{_ovpn_client} = 1;
    }

    # name is a whois-only param (for now)
    $tunnel->{_name} = $conf->{fn_name};

    return $tunnel;
}

sub delete {
    my ($self) = @_;

    my $l = Funknet::ConfigFile::Tools->encryption;
    my $openvpn_conf_dir = $l->{openvpn_conf_dir};

    # generate a filename for our config file 
    $self->{_ovpn_file} = $openvpn_conf_dir . '/' . $self->{_name} . '.conf';

    # create a SystemFile object on that path
    my $ovpn_file = Funknet::Config::SystemFile->new( text  => undef,
                                                      user  => 'openvpn',
                                                      group => 'openvpn',
                                                      mode  => '0600',
						      path  => $self->{_ovpn_file} );
    
    return $ovpn_file->delete;
}

sub create {
    my ($self, $inter) = @_;

    my $l = Funknet::ConfigFile::Tools->encryption;
    my $openvpn_conf_dir = $l->{openvpn_conf_dir};

    # stash the if-index
    $self->{_ovpn_inter} = $inter;
    
    # we only support OpenVPN over tuns, not tap. 
    #if ($self->{_type} eq 'openvpn') {
	$self->{_ovpn_type} = 'tun';
    #}
    
    # stash the interface number this will get in the object
    # (firewall rule gen needs this later)
    $self->{_ifname} = "$self->{_ovpn_type}$inter";

    # allocate a port
    # here we use 5000+ifindex
    $self->{_ovpn_port} = 5000 + $self->{_ovpn_inter};

    # generate a filename for our pidfile
    $self->{_ovpn_pidfile} = '/var/run/openvpn.'.$self->{_name}.'.pid';
    
    # generate a filename for our config file (from the whois)
    $self->{_ovpn_file} = $openvpn_conf_dir . '/' . $self->{_name} . '.conf';    
    
    # get our config text
    my $ovpn_conf = _gen_openvpn_conf($self);
 
    my $ovpn_file = Funknet::Config::SystemFile->new( text  => $ovpn_conf,
                                                      user  => 'openvpn',
                                                      group => 'openvpn',
                                                      mode  => '0600',
						      path  => $self->{_ovpn_file} );
					      
    return $ovpn_file;
}

sub initialise {
     my ($self) = @_;
     # decide if we're going to be client or server.
     # (ignoring NAT/dynamic issues here)
     # 
     # the 'top' endpoint in the object will be the server, 'bottom' is the client. 
     if ($self->{_order}) {
          $self->{_ovpn_client} = 1;
     } else {
          $self->{_ovpn_server} = 1;
     }
}

sub tunparams {
    my ($self, $tunparams) = @_;
    if (defined $tunparams) {
	$self->{_ovpn_port} = $tunparams->{port};
    }
    return { port => $self->{_ovpn_port} };
}

sub enc_data {
    my ($self, $enc_data) = @_;
    $self->{_ovpn_cert} = $enc_data->{certfile_path};
    $self->{_ovpn_key}  = $enc_data->{keyfile_path};
    $self->{_ovpn_ca}   = $enc_data->{cafile_path};
}

sub ifsym {
    return 'tun';
}

sub valid_type {
    my ($type) = @_;
    $type eq 'tun' && return 1;
    $type eq 'tap' && return 1;
    return 0;
}

sub restart_cmd {
    my ($self) = @_;
    return Funknet::Config::CommandSet->new( cmds => [ '/etc/init.d/openvpn restart' ],
					     target => 'host',
					   );
}

sub nat_firewall_rules {
    my ($self) = @_;
    my @rules_out;

    # we need nat rules for openvpn: 
    #
    # because we don't put the port number for openvpn in the object,
    # there's no way to guarantee that each end gets the same number.
    # really, we'd like the port number assignments to be private to
    # each node, not shared between endpoints.
    # 
    # so, we tell every client that its server is on port 1194, and on
    # the server DNAT incoming port 1194 based on source IP address to
    # whatever that client's locally assigned port is.
    #
    # This keeps knowledge of the assigned ports on the server only,
    # and the traffic actually visible on the network is all port
    # 1194.
    
    if ($self->{_ovpn_server}) {
         push (@rules_out,
               Funknet::Config::FirewallRule->new(
                                                  type                => 'nat',
                                                  proto               => 'udp',
                                                  destination_address => $self->{_local_endpoint},
                                                  source_address      => $self->{_remote_endpoint},
                                                  destination_port    => 1194,
                                                  to_addr             => $self->{_local_endpoint},
                                                  to_port             => $self->{_ovpn_port},
                                                  source              => $self->{_source},));
    }
    return (@rules_out);
}

sub filter_firewall_rules {
    my ($self) = @_;
    my @rules_out;

    @rules_out = $self->SUPER::firewall_rules();

    if ($self->{_ovpn_server}) {
         push (@rules_out, 
               Funknet::Config::FirewallRule->new(
                                                  proto               => 'udp',
						  direction	      => 'out',
                                                  source_address      => $self->{_local_endpoint},
                                                  destination_address => $self->{_remote_endpoint},
                                                  source_port         => $self->{_ovpn_port},
                                                  source              => $self->{_source},));
         push (@rules_out, 
               Funknet::Config::FirewallRule->new(
                                                  proto               => 'udp',
						  direction	      => 'in',
                                                  source_address      => $self->{_remote_endpoint},
                                                  destination_address => $self->{_local_endpoint},
                                                  destination_port    => $self->{_ovpn_port},
                                                  source              => $self->{_source},));
    }

    if ($self->{_ovpn_client}) {
         push (@rules_out, 
               Funknet::Config::FirewallRule->new(
                                                  proto               => 'udp',
						  direction	      => 'out',
                                                  source_address      => $self->{_local_endpoint},
                                                  destination_address => $self->{_remote_endpoint},
                                                  destination_port    => 1194,
                                                  source              => $self->{_source},));
         push (@rules_out, 
               Funknet::Config::FirewallRule->new(
                                                  proto               => 'udp',
						  direction	      => 'in',
                                                  source_address      => $self->{_remote_endpoint},
                                                  destination_address => $self->{_local_endpoint},
                                                  source_port	      => 1194,
                                                  source              => $self->{_source},));
    }

    return (@rules_out);
}

sub tunnel_ovpn_file {
    my ($self) = @_;
    return $self->{_ovpn_file};
}    

sub _gen_openvpn_conf {
    my ($self) = @_;
    my $config;

    if ($self->{_ovpn_client}) {

	$config = <<"CLIENTCONFIG";
# autogenerated openvpn.conf
# tunnel $self->{_name}
# from $self->{_local_endpoint} to $self->{_remote_endpoint}
#
# we are client.
#
dev            $self->{_ifname}
remote         $self->{_remote_endpoint}
nobind
ifconfig       $self->{_local_address} $self->{_remote_address}
user           openvpn 
group          openvpn
port           1194
tls-client
ca             $self->{_ovpn_ca}
ns-cert-type   server
replay-persist /var/run/replay.store.$self->{_ovpn_inter}
cert           $self->{_ovpn_cert}
key            $self->{_ovpn_key}
ping           15
ping-restart   60
persist-key
persist-tun
verb           5
writepid       $self->{_ovpn_pidfile}
CLIENTCONFIG
    
    } elsif ($self->{_ovpn_server}) {

	$config = <<"SERVERCONFIG";
# autogenerated openvpn.conf
# tunnel $self->{_name}
# from $self->{_local_endpoint} to $self->{_remote_endpoint}
#
# we are server.
#
dev            $self->{_ifname}
local          $self->{_local_endpoint}
ifconfig       $self->{_local_address} $self->{_remote_address}
user           openvpn
group          openvpn
port           $self->{_ovpn_port}
tls-server
ca             $self->{_ovpn_ca}
ns-cert-type   client
dh             dh1024.pem
replay-persist /var/run/replay.store.$self->{_ovpn_inter}
cert           $self->{_ovpn_cert}
key            $self->{_ovpn_key}
ping           15
ping-restart   60
persist-key
persist-tun
verb           5
writepid       $self->{_ovpn_pidfile}
SERVERCONFIG
    }
    return $config;
}

sub _parse_openvpn_conf {
    my ($text) = @_;

    my $config;
    for my $line ( split /\n/, $text) {
	
	# skip blank lines; comments
	next unless $line;
	next if $line =~ /^#/;

	my ($key, $val) = $line =~ m!^(\w+)\s+(.*)$!;
	next unless ($key);
	
	$config->{$key} = $val;
    }
    
    # hacktastic: we need both endpoints, but openvpn.conf
    # doesn't... we parse out our "from blah to blah" comment...

    my ($local_endpoint, $remote_endpoint) = $text =~ /from (.+) to (.+)/;
    $config->{fn_local_endpoint}  = $local_endpoint;
    $config->{fn_remote_endpoint} = $remote_endpoint;

    # we also need the name of the tunnel
    
    my ($tunnel) = $text =~ /tunnel (.+)/;
    $config->{fn_name} = $tunnel;

    return $config;
}

1;
