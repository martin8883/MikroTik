# MikroTik
Perl modules for use with MikroTiks RouterOS. Short guide in this file, comprehensive documentation will follow as POD. Modules will be available at CPAN in future.  

## MikroTik::API

### Quickstart
```perl
use MikroTik::API;
my $api = MikroTik::API->new({
	host => 'mikrotik.example.org',
	username => 'whoami',
	password => 'SECRET',
});
my ( $ret_get_identity, @aoh_identity ) = $api->query( '/system/identity/print', {}, {} );
print "Name of router: $aoh_identity[0]->{name}\n";
```
See examples below for more information.

### Examples
Copy config/credentials.cfg.example to config/credentials and adapt these values.  
Run perl bin/get_identity.pl to show the name of the router.  
See other examples.

### Parameters to the constructor new()
host: host as FQDN or IP address  
username: username of user with api permissions  
password: self explaining  
use_ssl : set to 1 if api-ssl should be used  
port : set if you changed default port (8728 for api and 8729 for api-ssl)  
debug : set beween 0 (none) and 5 (most) for debug messages  

### Methods
connect() : Connect to the router, will be automatically called by constructor if host is set  
login(): Will login and is also automatically called when additionally username and password are set  
logout(): self explaining  
cmd(): used for get, set, remove and so on  
query(): retrieve information from the router  
get_by_key(): return datasets as hash-of-hashes  

### Requirements
- Perl v5.10 or above  
- Modules: Config::General, Data::Dumper, Digest::MD5, IO::Socket::INET, IO::Socket::SSL, Moose  

