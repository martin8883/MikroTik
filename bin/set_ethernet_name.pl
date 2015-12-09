#!/usr/bin/perl
use strict;
use warnings;

### Example for combination of query() and cmd(): set name of ethernet interface by default-name

# ignore these four lines, they are just for getting correct path while executing from anywhere
use File::Basename;
use File::Spec;
use lib dirname(File::Spec->rel2abs(__FILE__)) . '/..';
my $abspath = dirname(File::Spec->rel2abs(__FILE__));

use Config::General;
use Data::Dumper;
use MikroTik::API;

if ( not ( defined $ARGV[0] && defined $ARGV[1] ) ) {
	die 'USAGE: $0 <default name> <new name>';
}

my %config = Config::General->new( $abspath . '/../config/credentials.cfg' )->getall();
my $api = MikroTik::API->new({
	host => $config{host},
	username => $config{username},
	password => $config{password},
	use_ssl => 1,
});

my ( $ret_interface_print, @interfaces ) = $api->query('/interface/print', { '.proplist' => '.id,name' }, { type => 'ether', 'default-name' => $ARGV[0] } );
if( $interfaces[0]->{name} eq $ARGV[1] ) {
	print "Name is already set to this value\n";
}
else {
	my $ret_set_interface = $api->cmd( '/interface/ethernet/set', { '.id' => $interfaces[0]->{'.id'}, 'name' => $ARGV[1] } );
	print "Name changed\n";
}

$api->logout();
