#!/usr/bin/perl
use strict;
use warnings;

### Example for method get_by_key(): show all ethernet interfaces of router by command line

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

my %interface = $api->get_by_key('/interface/ethernet/print', 'name' );
# Some preparation for sorting
map {
	$interface{$_}->{'.id'} =~ /^\*(.*)/;
	$interface{$_}->{id_dec} = unpack( 's', pack 's', hex($1) );
} keys %interface;
print "Default-Name Name           active running\n";
foreach my $name ( sort { $interface{$a}->{'id_dec'} <=> $interface{$b}->{'id_dec'} } keys %interface ) {
	printf("%-12.12s %-14.14s %-6.6s %-7.7s\n", $interface{$name}->{'default-name'}, $name, $interface{$name}->{disabled} eq 'true' ? 'no' : 'yes', $interface{$name}->{running}  );
}

$api->logout();
