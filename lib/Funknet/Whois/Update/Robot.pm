# Copyright (c) 2004
#      The funknet.org Group.
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

=head1 NAME

Funknet::Whois::Update::Robot

=head1 DESCRIPTION

Use Email::Robot to implement a pureperl whois-by-email updater.

=head1 FUNCTIONS

=cut

package Funknet::Whois::Update::Robot;
use strict;

use Email::Robot;
use base qw/ Email::Robot /;

use Data::Dumper;

sub success_text {
    my ($self, $keyid, $header, @objects) = @_;

    my $text = << "MAILTEXT";

Your update was SUCCESSFUL.

$header

The following objects were processed.

==== BEGIN PGP SIGNED PART (keyID(s): $keyid) ====

MAILTEXT

    for my $object (@objects) {

	my $type = $object->{_order}->[0];
	my $name;
	{
	    no strict 'refs';
	    # fucking yuck
	    $name = &{"Net::Whois::RIPE::Object::$type"}($object);
	}
	
	$text .= "Update OK: [$type] $name\n";
    }

    $text .= << "MAILTEXT";

==== END PGP SIGNED PART ====

FUNKNET Database Maintenance Department (Perl Section)

MAILTEXT

      return $text;
}

sub failure_text {
    my ($self, $keyid, $header, @objects) = @_;
    my $errorlist = join "\n", $self->error();
    
    my $text = << "MAILTEXT";

Part of your update FAILED.

$header

For help see <http://www.funknet.org/db/> or
send a message to auto-dbm\@funknet.org
 with 'help' in the subject line

Objects without errors have been processed.

==== BEGIN PGP SIGNED PART (keyID(s): $keyid) ====

MAILTEXT

    for my $object (@objects) {
	$text .= "Update FAILED: ".($object->error)."\n";
	$text .= $object->text;
	$text .= "\n";
    }

    $text .= << "MAILTEXT";

==== END PGP SIGNED PART ====

FUNKNET Database Maintenance Department (Perl Section)

MAILTEXT

      return $text;

}

sub fatalerror_text {
    my ($self, $error_text) = @_;
    return <<"MAILTEXT";

An error occurred processing your update request.
$error_text

MAILTEXT

}


1;
