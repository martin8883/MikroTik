#!/usr/bin/perl
use strict;
use warnings;

### Example for method cmd(): set identity of router by command line

# ignore these four lines, they are just for getting correct path while executing from anywhere
use File::Basename;
use File::Spec;
use lib dirname(File::Spec->rel2abs(__FILE__)) . '/..';
my $abspath = dirname(File::Spec->rel2abs(__FILE__));

use Config::General;
use Data::Dumper;
use MikroTik::API;

if ( not defined $ARGV[0] ) {
	die 'USAGE: $0 <new name>';
}

my %config = Config::General->new( $abspath . '/../config/credentials.cfg' )->getall();
my $api = MikroTik::API->new({
	host => $config{host},
	username => $config{username},
	password => $config{password},
	use_ssl => 1,
});

my $ret_set_identity = $api->cmd( '/system/identity/set', { 'name' => $ARGV[0] } );
print "Name set\n";

$api->logout();
