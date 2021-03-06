# Copyright (c) 2003
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

package Funknet::Whois;
use strict;

=head1 NAME

Funknet::Whois

=head1 DESCRIPTION

Routines for dealing with whois objects.
   
=cut

=cut

use vars qw/ @EXPORT_OK @ISA /;
@EXPORT_OK = qw/ parse_object check_auth 
                 object_exists get_object 
                 pretty_object get_object_inverse
                 load_template /;
@ISA = qw/ Exporter /;
use Exporter; 

use IO::Scalar;
use Funknet::Whois::Object;
use Funknet::Whois::Templates;

=head2 parse_object

Takes a whois object as text, returns a Funknet::Whois::Object
object.

=cut

sub parse_object {
    my ($object_text) = @_;
    my $object = Funknet::Whois::Object->new($object_text);
    return $object;
}

=head2 load_template {

Given an object type returns a Funknet::Whois::Object with the methods
defined, but no values, and no errors recorded. 

=cut

sub load_template {
    my ($object_type) = @_;

    my $object_text = Funknet::Whois::Templates::tmpl($object_type);
    defined $object_text or return undef;

    my $object = Funknet::Whois::Object->new($object_text, NoValidate => 1);
    return $object;
}

=head2 check_auth

Takes an object and keyid, checks auth. 

=cut 

sub check_auth {
    my ($object, $keyid) = @_;
    my $auth_ok;

    my $w = Funknet::Whois::Client->new( 'whois.funknet.org', 
                                         Source => 'FUNKNET',
                                         Port   => 4343,
                                       );
    $w->type('mntner');

  AUTH:
    for my $mnt_by ($object->mnt_by) {
	my $mntner = $w->query($mnt_by);
	for my $auth ($mntner->auth) {
	    if ($auth eq "PGPKEY-$keyid") {
		$auth_ok = 1;
		last AUTH;
	    }
	}
    }
    return $auth_ok;
}

=head2 check_zone_auth

Takes a zone and a keyid and checks that that key is authorised to
delegate that zone for reverse dns. We do this by converting the 
'domain' attribute we're passed into an inetnum and retrieving the
corresponding object. We then get the mntner for that inetnum, and
check that the keyid we've been given is in the list of keys on that
mntner.  

=cut

sub check_zone_auth {
    my ($zone, $keyid) = @_;

    $keyid =~ s/.*([A-F0-9]{8})$/$1/;

    my $inetnum;
    if 
	($zone =~ /(\d+).(\d+).(\d+).in-addr.arpa/) {
	    $inetnum = "$3.$2.$1.0";
    } 
    elsif 
	($zone =~ /(\d+).(\d+).in-addr.arpa/) {
	    $inetnum = "$2.$1.0.0";
    }
    elsif 
	($zone =~ /(\d+).in-addr.arpa/) {
           $inetnum = "$1.0.0.0";
    }

    my $w = Funknet::Whois::Client->new( 'whois.funknet.org' );
    $w->type('inetnum');
    my $in = $w->query($inetnum);
    
    return check_auth($in, $keyid);
}
    
sub object_exists {
    my ($object) = @_;
    ref $object eq 'Funknet::Whois::Object' or return undef;

    # check type, extract primary key.

    # do lookup

    # prune whitespace

    # compare

    return 1;
}

=head2 get_object

Takes a type string and a primary key, returns the object as a
Funknet::Whois::Object

=cut

sub get_object {
    my ($type, $name) = @_;
    my $w = Funknet::Whois::Object->new( 'whois.funknet.org' );
    $w->type($type);
    my $obj = $w->query($name);
    if (defined $obj && scalar @{ $obj->{_order} }) {
	return $obj;
    } else { 
	return undef;
    }
}

=head2 get_object_inverse

Takes a type string, inverse key name and inverse key data, returns
the object as a Funknet::Whois::Object.

=cut

sub get_object_inverse {
    my ($type, $key, $value) = @_;
    my $w = Funknet::Whois::Client->new( 'whois.funknet.org' );
    $w->type($type);
    $w->inverse_lookup($key);
    my $obj = $w->query($value);
    if (defined $obj && scalar @{ $obj->{_order} }) {
	return $obj;
    } else { 
	return undef;
    }
}


1;
