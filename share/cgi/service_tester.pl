#!/usr/bin/perl -w
#-----------------------------------------------------------------
# service_tester.pl
# Author: Edward Kawas <edward.kawas@gmail.com>,
# For copyright and disclaimer see below.
#
# $Id: service_tester.pl,v 1.1 2008/02/21 00:21:27 kawas Exp $
#
# BETA
#
# This script goes ahead an asks a registry what services exist
# and then goes ahead and calls them all determining who is alive
# and who is not. This info is kept in a file as XML.
#
# Configurable options:
# 	TIMEOUT 		- the timeout in seconds to wait for each service
#	THREAD_COUNT 	- the number of workers that will call services
#	CATEGORIES		- the moby service categories to test
#	URL				- the registry endpoint <optional>
#	URI				- the registry namespace <optional>
#   DIRECTORY		- the place to store details between jobs <optional>
#
# IMPORTANT NOTE:
# This script currently does not run on windows because of the 
# IPC::Shareable module. A work around is being looked into.
#
# This script works on unix/linux. Other machines have not been
# tested.
#-----------------------------------------------------------------

use strict;
use warnings;

use MOBY::Config;
use MOBY::Client::Central;
use SOAP::Lite;
use XML::LibXML;
# Because of this library, cannot run on windows
use IPC::Shareable;

######-------USER CONFIGURABLE PARAMETERS-------######
# how long in seconds to wait for a service to respond
my $TIMEOUT = 20;

# the total number of 'threads' to use ...
my $THREAD_COUNT = 15;

# the categories of services to ping
my @CATEGORIES = qw / moby /;

######-------------------------------------------######

# the registry to query
my $URL = $ENV{MOBY_SERVER} || 'http://moby.ucalgary.ca/moby/MOBY-Central.pl';
my $URI = $ENV{MOBY_URI} || 'http://moby.ucalgary.ca/MOBY/Central';

# The directory to store the job details
my $CONF  = MOBY::Config->new;
my $DIRECTORY = $CONF->{mobycentral}->{service_tester_path} || '/tmp/';

# hashes whose key is the service provider and the value is an array of service names
my %ALIVE     = ();
my $FILENAME  = 'isAliveStats.xml';

# this is just to test if I'm going to have permissions
# right now, rather than an hour from now...  Arghghg!
open( OUT, ">>$DIRECTORY/$FILENAME" ) || die("Cannot Open File '$DIRECTORY/$FILENAME' $!");
close OUT;

# create some shared variables
my $alive_handle = tie %ALIVE, 'IPC::Shareable', undef, { destroy => 'yes' };

# create the central client and get all service providers once
my $central =
	  MOBY::Client::Central->new(
		Registries => { 
			mobycentral => { 
				URL => $URL,
				URI => $URI
			}
		}
	);
my @providers = $central->retrieveServiceProviders();

foreach my $cat (@CATEGORIES) {
	foreach my $authURI (@providers) {
		my ( $second, $minute, $hour, @whatever ) = localtime();
		print "Finding services registered by '$authURI' as '$cat' @ $hour:$minute:$second\n";
		my ( $services, $reg ) = $central->findService( Registry => "mobycentral",category => $cat, authURI => $authURI );
		( $second, $minute, $hour, @whatever ) = localtime();
		print "Services found "
	  	. scalar @$services
	  	. "... processing @ $hour:$minute:$second \n";
 
		my $count = 0;
		print "\tservice count: " . scalar (@$services) . "\n";
		foreach (@$services) {
			# ignore test services
			next if  $_->authority eq 'samples.jmoby.net';
			wait, $count-- while $count >= $THREAD_COUNT;
			$count++;
			my $pid = fork();
			$count-- unless defined $pid;
			do { IPC::Shareable->clean_up_all; die "Couldn't fork: $!"; }
		  	unless defined $pid;
			if ($pid) {
				# parent - do nothing ...s
			} elsif ( $pid == 0 ) {
				my $name = $_->name;
				my $auth = $_->authority;
				my $url  = $_->URL;

				do {
					# dont process localhost addresses ...
					exit(0);
				} if $url =~ /localhost/;
	
				# child - stuff to do goes here
				#print "Calling: " . $auth . "," . $name . "\n";
				my $soap =
				  SOAP::Lite->uri("http://biomoby.org/")
				  ->proxy( $url, timeout => $TIMEOUT )->on_fault(
					sub {
						my $soap = shift;
						my $res  = shift;
	
						#TODO add to DEAD hash ...
						$alive_handle->shlock();
						$ALIVE{$auth} = () if not exists $ALIVE{$auth};
						push @{ $ALIVE{$auth} }, {name=>$name, alive=>undef};
						$alive_handle->shunlock();
	
						#print "\t" . $auth . "," . $name . " ~isAlive\n";
						exit(0);
					}
				  );

				my $input = _empty_input();
				my $out   =
				  $soap->$name( SOAP::Data->type( 'string' => "$input" ) )->result;
				do {
					#TODO add to ALIVE hash ...
					#print "\t" . $auth . "," . $name . " isAlive\n";
					$alive_handle->shlock();
					$ALIVE{$auth} = () if not exists $ALIVE{$auth};
					push @{ $ALIVE{$auth} }, {name=>$name, alive=>1};
					$alive_handle->shunlock();
					exit(0);
				} if $out;
				do {
					#TODO add to DEAD hash ...
					#print "\t" . $auth . "," . $name . " ~isAlive\n";
					$alive_handle->shlock();
					$ALIVE{$auth} = () if not exists $ALIVE{$auth};
					push @{ $ALIVE{$auth} }, {name=>$name, alive=>undef};
					$alive_handle->shunlock();
					exit(0);
				} unless $out;
			} else {
				IPC::Shareable->clean_up_all;
				die "couldn�t fork: $!\n";
			}
		}

		# dont proceed until we are completed with the first batch of children!
		wait, $count-- while $count > 0;
		( $second, $minute, $hour, @whatever ) = localtime();
		print "Testing of '$cat' services from '$authURI' completed @ $hour:$minute:$second \n";
	}
}

my $doc = XML::LibXML::Document->new( "1.0", "UTF-8" );
my $root = $doc->createElement('Services');
$doc->setDocumentElement($root);

for my $auth ( sort keys %ALIVE ) {
	my $element = $doc->createElement('authority');
	$element->setAttribute( 'id', $auth );
	my @services = @{$ALIVE{$auth}};
	next unless @services;
	foreach my $s (@services) {
		next unless $s;
		my $child = $doc->createElement('service');
		$child->setAttribute( 'id', $auth . ',' . $s->{name} );
		$child->appendText(($s->{alive} ? 'true' : 'false'));
		$element->appendChild($child);
	}
	$root->appendChild($element);
}

IPC::Shareable->clean_up_all;

open( OUT, ">$DIRECTORY/$FILENAME" ) || die("Cannot Open File $DIRECTORY/$FILENAME $!");
print OUT $doc->toString(1);
close OUT;

sub _empty_input {
	return <<'END_OF_XML';
<?xml version="1.0" encoding="UTF-8"?>
<moby:MOBY xmlns:moby="http://www.biomoby.org/moby">
  <moby:mobyContent>
  </moby:mobyContent>
</moby:MOBY>
END_OF_XML
}
