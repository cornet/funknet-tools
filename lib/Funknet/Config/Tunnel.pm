package Funknet::Config::Tunnel;
use strict;

use Funknet::Config::Validate qw/ is_ipv4 is_ipv6 is_valid_type is_valid_proto /;
use Funknet::Config::Tunnel::BSD;
use Funknet::Config::Tunnel::IOS;
use Funknet::Config::Tunnel::Linux;
use Funknet::Config::Tunnel::Solaris;

=head1 NAME

Funknet::Config::Tunnel

=head1 DESCRIPTION

This is the generic Tunnel class. It reads the local_os parameter set
by higher-level code, and calls the appropriate routines in the
OS-specific classes, returning an object blessed into a specific
class.

=head1 EXTENDING

Adding a new OS' tunnel implementation requires the following changes:
extend sub new to read the new local_os parameter; likewise
new_from_ifconfig. Add a new module Funknet::Config::Tunnel::NewOS.pm
and use it in this module. Add the new OS' local_os flag to
Funknet::Config::Validate.pm. Implement specific methods in NewOS.pm. 

=cut

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    my $l = Funknet::Config::ConfigFile->local;

    # is this an interface we should be ignoring?

    my @ignore_if = Funknet::Config::ConfigFile->ignore_if;
    if (defined $args{ifname} && (grep /$args{ifname}/, @ignore_if)) {
	warn "ignoring $args{ifname}";
	return undef;
    }
    
    unless (defined $args{source} && ($args{source} eq 'whois' || $args{source} eq 'host')) {
	warn "missing source";
	return undef;
    } else {
	$self->{_source} = $args{source};
    }

    unless (defined $args{type} && is_valid_type($args{type})) {
	warn "missing or invalid type";
	return undef;
    } else {
	$self->{_type} = $args{type};
    }

    unless (defined $args{proto} && is_valid_proto($args{proto})) {
	warn "missing or invalid protocol";
	return undef;
    } else {
	$self->{_proto} = $args{proto};
    }
    
    if ($self->{_proto} eq '4') {
	for my $addr (qw/ local_address remote_address local_endpoint remote_endpoint / ) {
	    unless (is_ipv4 ($args{$addr})) {
		warn "invalid ipv4 address";
		return undef;
	    } else {
		$self->{"_$addr"} = $args{$addr};
	    }
	} 
    } elsif ($self->{_proto} eq '6') {
	for my $addr (qw/ local_address remote_address / ) {
	    unless (is_ipv6 ($args{$addr})) {
		warn "invalid ipv6 address";
		return undef;
	    } else {
		$self->{"_$addr"} = $args{$addr};
	    }
	}
	for my $addr (qw/ local_endpoint remote_endpoint / ) {
	    unless (is_ipv4 ($args{$addr})) {
		warn "invalid ipv4 address";
		return undef;
	    } else {
		$self->{"_$addr"} = $args{$addr};
	    }
	}
    }
    if ($self->{_source} eq 'host') {
	if (defined $args{interface}) {
	    $self->{_interface} = $args{interface};
	} else {
	    warn "missing interface for host tunnel";
	}
    }
	    
    # rebless if we have a specific OS to target 
    # for this tunnel endpoint.

    $l->{os} eq 'bsd' and 
	bless $self, 'Funknet::Config::Tunnel::BSD';
    $l->{os} eq 'ios' and 
	bless $self, 'Funknet::Config::Tunnel::IOS';
    $l->{os} eq 'linux' and
	bless $self, 'Funknet::Config::Tunnel::Linux';
    $l->{os} eq 'solaris' and
	bless $self, 'Funknet::Config::Tunnel::Solaris';

    return $self;
}

sub as_string {
    my ($self) = @_;
    
    return 
	"$self->{_type}:\n" .
	"$self->{_local_endpoint} -> $self->{_remote_endpoint}\n" . 
	"$self->{_local_address} -> $self->{_remote_address}\n";
}

sub as_hashkey {
    my ($self) = @_;
    
    return 
	"$self->{_type}-" .
	"$self->{_local_endpoint}-$self->{_remote_endpoint}-" . 
	"$self->{_local_address}-$self->{_remote_address}";
}

sub new_from_ifconfig {
    my ($class, $if) = @_;
    my $l = Funknet::Config::ConfigFile->local;
    
    if ($l->{os} eq 'bsd') {
	return Funknet::Config::Tunnel::BSD->new_from_ifconfig( $if );
    }
    if ($l->{os} eq 'linux') {
	return Funknet::Config::Tunnel::Linux->new_from_ifconfig( $if );
    }
    if ($l->{os} eq 'solaris') {
	return Funknet::Config::Tunnel::Solaris->new_from_ifconfig( $if );
    }
    return undef;
}

sub interface {
    my ($self) = @_;
    return $self->{_interface};
}

sub type {
    my ($self) = @_;
    return $self->{_type};
}

sub local_os {
    my ($self) = @_;
    return $self->{_local_os};
}
1;
