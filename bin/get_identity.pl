#!/usr/bin/perl
use strict;
use warnings;

### Example for method query(): get identity of router by command line

# ignore these four lines, they are just for getting correct path while executing from anywhere
use File::Basename;
use File::Spec;
use lib dirname(File::Spec->rel2abs(__FILE__)) . '/..';
my $abspath = dirname(File::Spec->rel2abs(__FILE__));

use Config::General;
use Data::Dumper;
use MikroTik::API;

my %config = Config::General->new( $abspath . '/../config/credentials.cfg' )->getall();
my $api = MikroTik::API->new({
	host => $config{host},
	username => $config{username},
	password => $config{password},
	use_ssl => 1,
});

my ( $ret_get_identity, @aoh_identity ) = $api->query( '/system/identity/print', {}, {} );
print "Name of router: $aoh_identity[0]->{name}\n";

$api->logout();
