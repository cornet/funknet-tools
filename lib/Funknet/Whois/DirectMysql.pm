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

package Funknet::Whois::DirectMysql;
use strict;
use DBI;
use base qw/ DBI /;

=head1 NAME

Funknet::Whois::DirectMysql

=head1 DESCRIPTION

Provides a DBI object connected to the whois db's mysql database.

=head1 METHODS

=head2 new

Call with no params, returns a $dbh.

=cut

sub new {

    # get connection params from whois config file

    my $config;
    if (defined $ENV{WHOISD_CONFIG}) {
	$config = $ENV{WHOISD_CONFIG};
    } else {
	$config = '/usr/local/whoisd-funknet/conf/rip.config.FUNKNET';
    }
    
    my ($host, $port, $user, $pass, $name);
    open CONF, $config
      or die "couldn't open whoisd config file $config: $!";
    while (<CONF>) {
	next unless /^UPDSOURCE FUNKNET (.*),(.*),(.*),(.*),(.*) /;
	($host, $port, $user, $pass) = ($1, $2, $3, $4, $5);
	last;
    }
    close CONF;
    
    unless (defined $host &&
	    defined $port &&
	    defined $user &&
	    defined $pass) {
	die "failed to get database params";
    }
    
    # connect to database

    my $dbh = DBI->connect("DBI:mysql:database=$name,host=$host,port=$port",$user,$pass);
    unless ($dbh) {
	die "failed to connect to $name: $DBI::errstr";
    }
	
    bless $dbh, "Funknet::Whois::DirectMysql";
    return $dbh;
}
