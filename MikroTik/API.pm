# API for RouterOS based MikroTik hardware
# Martin Gojowsky <martin@gojowsky.de>
#
# Object-Orientated Rebuild of prior contributions, based on:
# - inital release from cheesegrits in MikroTik forum: http://forum.mikrotik.com/viewtopic.php?p=108530#p108530
# - added timeoutparameter and fixes by elcamlost: https://github.com/elcamlost/mikrotik-perl-api/commit/10e5da1fd0ccb4a249ed3047c1d22c97251f666e
# - SSL support by akschu: https://github.com/akschu/MikroTikPerl/commit/9b689a7d7511a1639ffa2118c8e549b5cec1290d
#
# Design decisions:
# - Use of Moose for OO
# - higher compilation time of Moose based lib negligible because of slow I/O operations
# - Moose is more common than Moo or similar
#
# Requirements:
# - Perl v5.10 or above
# - Modules (name of debian package in suite jessie):
#   * Data::Dumper (perl)
#   * Digest::MD5 (perl)
#   * IO::Socket::INET (perl-base)
#   * IO::Socket::SSL (libio-socket-ssl-perl)
#   * Moose (libmoose-perl)
#

package MikroTik::API;
$VERSION = '0.2';
use Moose;
use namespace::autoclean;
has 'host' => ( is => 'rw', reader => 'get_host', writer => 'set_host', isa => 'Str' );
has 'port' => ( is => 'ro', reader => '_get_port', writer => 'set_port', isa => 'Int' );
has 'username' => ( is => 'rw', reader => 'get_username', writer => 'set_username', isa => 'Str' );
has 'password' => ( is => 'rw', reader => 'get_password', writer => 'set_password', isa => 'Str' );
has 'use_ssl' => ( is => 'rw', reader => 'get_use_ssl', writer => 'set_use_ssl', isa => 'Bool' );
has 'socket' => ( is => 'rw', reader => 'get_socket', writer => 'set_socket', isa => 'IO::Socket' );
has 'debug' => ( is => 'rw', reader => 'get_debug', writer => 'set_debug', isa => 'Int', default => 0 );

use v5.10;
use Data::Dumper;
use Digest::MD5;
use IO::Socket::INET;
use IO::Socket::SSL;

### Constructor parameters
### REQUIRED
#   host : FQDN or ip address of host
#	username : Username
#	password : Password,
### OPTIONAL
#	use_ssl : set to 1 if api-ssl should be used
#	port : set if you changed default port (8728 for api and 8729 for api-ssl)
#	debug : set beween 0 (none) and 5 (most) for debug messages

sub BUILD {
	my ($self) = @_;
	if ( $self->get_host() ) {
		$self->connect();
		if ($self->get_username() && $self->get_password() ) {
			$self->login();
		}
	}
	return $self;
}

### Overrridden accessors with extended functionality

sub get_port {
	my ( $self ) = @_;
	$self->_get_port()
		? $self->_get_port()
		: $self->get_use_ssl()
			? 8729
			: 8728
	;
}

### Public Methods

sub connect {
	my ( $self ) = @_;

	if ( ! $self->get_host() ) {
		die 'host must be set before connect()'
	}
	
	if ( $self->get_use_ssl() ) {
		$self->set_socket(
			IO::Socket::SSL->new(
				PeerAddr => $self->get_host(),
				PeerPort => $self->get_port(),
				Proto => 'tcp',
				SSL_cipher_list => 'HIGH',
			) or die "failed connect or ssl handshake ($!: ". IO::Socket::SSL::errstr() .')'
		);
	}
	else {
		$self->set_socket(
			IO::Socket::INET->new(
				PeerAddr => $self->get_host(),
				PeerPort => $self->get_port(),
				Proto	=> 'tcp'
			) or die "failed connect ($!)"
		);
	}
	if ( ! $self->get_socket() ) {
		die "socket creation failed ($!)";
	}
	return $self;
}

sub login {
	my ( $self ) = @_;
	
	if ( ! $self->get_username() && $self->get_password() ) {
		die 'username and password must be set before connect()';
	}
	if ( ! $self->get_socket() ) {
		$self->connect();
	}
	
	my @command = ('/login');
	my ( $retval, @results ) = $self->talk( \@command );
	my $challenge = pack("H*",$results[0]{'ret'});
	my $md5 = Digest::MD5->new();
	$md5->add( chr(0) );
	$md5->add( $self->get_password() );
	$md5->add( $challenge );
	
	@command = ('/login');
	push( @command, '=name=' . $self->get_username() );
	push( @command, '=response=00' . $md5->hexdigest() );
	( $retval, @results ) = $self->talk( \@command );
	if ( $retval > 1 ) {
		die $results[0]{'message'};
	}
	if ( $self->get_debug() > 0 ) {
		print 'Logged in to '. $self->get_host() .' as '. $self->get_username() ."\n";
	}
	
	return $self;
}

sub logout {
	my ($self) = @_;
	close $self->get_socket();
	$self->set_socket( undef );
}

sub cmd {
	my ( $self, $cmd, $attrs_href ) = @_;
	my @command = ($cmd);

	foreach my $attr ( keys %{$attrs_href} ) {
		push( @command, '='. $attr .'='. $attrs_href->{$attr} );
	}
	my ( $retval, @results ) = $self->talk( \@command );
	if ($retval > 1) {
		die $results[0]{'message'};
	}
	return ( $retval, @results );
}

sub query {
	my ( $self, $cmd, $attrs_href, $queries_href ) = @_;

	my @command = ($cmd);
	foreach my $attr ( keys %{$attrs_href} ) {
		push( @command, '='. $attr .'='. $attrs_href->{$attr} );
	}
	foreach my $query (keys %{$queries_href} ) {
		push( @command, '?'. $query .'='. $queries_href->{$query} );
	}
	my ( $retval, @results ) = $self->talk( \@command );
	if ($retval > 1) {
		die $results[0]{'message'};
	}
	return ( $retval, @results );
}

sub get_by_key {
	my ( $self, $cmd, $id ) = @_;
	$id ||= '.id';
	my @command = ($cmd);
	my %ids;
	my ( $retval, @results ) = $self->talk( \@command );
	if ($retval > 1) {
		die $results[0]{'message'};
	}
	foreach my $attrs ( @results ) {
		# TODO: Was soll das?
		my $key = '';
		foreach my $attr ( keys %{ $attrs } ) {
			my $val = $attrs->{$attr};
			if ($attr eq $id) {
				$key = $val;
			}
		}
		if ( $key ) {
			$ids{$key} = $attrs;
		}
	}
	return %ids;
}

### Semi-Public Methods (can be useful for advanced users, but too complex for daily use)

sub talk {
	my ( $self, $sentence_aref ) = @_;
	
	$self->_write_sentence( $sentence_aref );
	my ( @reply, @attrs );
	my $retval = 0;
	
	while ( ( $retval, @reply ) = $self->_read_sentence() ) {
		my %dataset;
		foreach my $line ( @reply ) {
			if ( my ($key, $value) = ( $line =~ /^=(\S+)=(.*)/s ) ) {
				$dataset{$key} = $value;
			}
		}
		push( @attrs, \%dataset ) if (keys %dataset);
		if ( $retval > 0 ) { last; }
	}
	return ( $retval, @attrs );
}

sub raw_talk {
	my ( $self, $sentence_aref ) = @_;
	
	$self->_write_sentence( $sentence_aref );
	my ( @reply, @response );
	my $retval = 0;
	
	while ( ( $retval, @reply ) = $self->_read_sentence() ) {
		foreach my $line ( @reply ) {
			push ( @response, $line );
		}
		if ( $retval > 0 ) { last; }
	}
	return ( $retval, @response );
}

### Internal Methods

sub _write_sentence {
	my ( $self, $sentence_aref ) = @_;

	foreach my $word ( @{$sentence_aref} ) {
		$self->_write_word( $word );
		if ( $self->get_debug() > 2 ) {
			print ">>> $word\n";
		}
	}
	$self->_write_word('');
}

sub _write_word {
	my ( $self, $word ) = @_;
	$self->_write_len( length $word );
	my $socket = $self->get_socket();
	print $socket $word;
}

sub _write_len {
	my ( $self, $len ) = @_;
	
	my $socket = $self->get_socket();
	if ( $len < 0x80 ) {
		print $socket chr($len);
	}
	elsif ($len < 0x4000) {
		$len |= 0x8000;
		print $socket chr(($len >> 8) & 0xFF);
		print $socket chr($len & 0xFF);
	}
	elsif ($len < 0x200000) {
		$len |= 0xC00000;
		print $socket chr(($len >> 16) & 0xFF);
		print $socket chr(($len >> 8) & 0xFF);
		print $socket chr($len & 0xFF);
	}
	elsif ($len < 0x10000000) {
		$len |= 0xE0000000;
		print $socket chr(($len >> 24) & 0xFF);
		print $socket chr(($len >> 16) & 0xFF);
		print $socket chr(($len >> 8) & 0xFF);
		print $socket chr($len & 0xFF);
	}
	else {
		print $socket chr(0xF0);
		print $socket chr(($len >> 24) & 0xFF);
		print $socket chr(($len >> 16) & 0xFF);
		print $socket chr(($len >> 8) & 0xFF);
		print $socket chr($len & 0xFF);
	}
}

sub _read_sentence {
	my ( $self ) = @_;

	my ( @reply );
	my $retval = 0;
	
	while ( my $word = $self->_read_word() ) {
		if ($word =~ /!done/) {
			$retval = 1;
		}
		elsif ($word =~ /!trap/) {
			$retval = 2;
		}
		elsif ($word =~ /!fatal/) {
			$retval = 3;
		}
		push( @reply, $word );
		if ( $self->get_debug() > 2 ) {
			print "<<< $word\n"
		}
	}
	return ( $retval, @reply );
}

sub _read_word {
	my ( $self ) = @_;
	
	my $ret_line = '';
	my $len = $self->_read_len();
	if ( $len > 0 ) {
		if ( $self->get_debug() > 3 ) {
			print "recv $len\n";
		}
		my $length_received = 0;
		while ( $length_received < $len ) {
			my $line = '';
			if ( ref $self->get_socket() eq 'IO::Socket::INET' ) {
				$self->get_socket()->recv( $line, $len );
			}
			else { # IO::Socket::SSL does not implement recv()
				$self->get_socket()->read( $line, $len );
			}
			$ret_line .= $line; # append to $ret_line, in case we didn't get the whole word and are going round again
			$length_received += length $line;
		}
	}
	return $ret_line;
}

sub _read_len {
	my ( $self ) = @_;

	if ( $self->get_debug() > 4 ) {
		print "start read_len\n";
	}
	
	my $len = $self->_read_byte();
	
	if ( ($len & 0x80) == 0x00 ) {
		return $len
	}
	elsif ( ($len & 0xC0) == 0x80 ) {
		$len &= ~0x80;
		$len <<= 8;
		$len += $self->_read_byte();
	}
	elsif ( ($len & 0xE0) == 0xC0 ) {
		$len &= ~0xC0;
		$len <<= 8;
		$len += $self->_read_byte();
		$len <<= 8;
		$len += $self->_read_byte();
	}
	elsif ( ($len & 0xF0) == 0xE0 ) {
		$len &= ~0xE0;
		$len <<= 8;
		$len += $self->_read_byte();
		$len <<= 8;
		$len += $self->_read_byte();	   
		$len <<= 8;
		$len += $self->_read_byte();	   
	}
	elsif ( ($len & 0xF8) == 0xF0 ) {
		$len = $self->_read_byte();
		$len <<= 8;
		$len += $self->_read_byte();
		$len <<= 8;
		$len += $self->_read_byte();	   
		$len <<= 8;
		$len += $self->_read_byte();  
	} 
	
	if ( $self->get_debug() > 4 ) {
		print "read_len got $len\n";
	}
	
	return $len;
}

sub _read_byte{
	my ( $self ) = @_;
	my $line = '';
	if ( ref $self->get_socket() eq 'IO::Socket::INET' ) {
		$self->get_socket()->recv( $line, 1 );
	}
	else { # IO::Socket::SSL does not implement recv()
		$self->get_socket()->read( $line, 1 );
	}
	return ord($line);
}

1;
