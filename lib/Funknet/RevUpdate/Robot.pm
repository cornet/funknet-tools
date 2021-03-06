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

=head1 NAME

Funknet::RevUpdate::Robot

=head1 DESCRIPTION

The specifically mail-robot related parts of the RevUpdate code.  See
Funknet::RevUpdate for the general delegation-checking and dynamic
update code.

We use Email::Robot, and provide specific implementations of the
message-text generating methods.

=head1 FUNCTIONS

=cut

package Funknet::RevUpdate::Robot;
use strict;

use Email::Robot;
use base qw/ Email::Robot /;

sub success_text {
    my ($self, $zone, @ns) = @_;
    my $ns_list = join "\n", @ns;

    return << "MAILTEXT";

Funknet Reverse Delegation result:

The zone $zone has been successfully delegated to:
$ns_list

Regards,
Dennis

MAILTEXT

}

sub failure_text {
    my ($self, $zone, @ns) = @_;
    my $ns_list = join "\n", @ns;
    my $errorlist = join "\n", $self->error();
    
    return << "MAILTEXT";

Funknet Reverse Delegation result:

Your request for the delegation of $zone to:
$ns_list

has failed for the following reason(s):
$errorlist

Commiserations,
Dennis

MAILTEXT

}

sub fatalerror_text {
    my ($self, $error_text) = @_;
    return <<"MAILTEXT";

An error occurred processing your reverse delegation request:
$error_text

Regards,
Dennis

MAILTEXT

}


1;

