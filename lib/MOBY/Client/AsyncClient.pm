#-----------------------------------------------------------------
# MOBY::Client::AsyncClient
# Author: Edward Kawas <edward.kawas@gmail.com>,
# For copyright and disclaimer see below.
#
# $Id: Utils.pm,v 1.9 2009/01/28 14:38:41 kawas Exp $
#-----------------------------------------------------------------

package MOBY::Client::AsyncClient;

use XML::LibXML;

use MOBY::Async::LSAE;
use MOBY::Async::WSRF;

use strict;

use vars qw /$VERSION/;
$VERSION = sprintf "%d.%02d", q$Revision: 1.9 $ =~ /: (\d+)\.(\d+)/;

$MOBY::Client::AsyncClient::Constants::DEBUG = 0;

#-----------------------------------------------------------------
# load all modules needed for my attributes
#-----------------------------------------------------------------

=head1 NAME

MOBY::Client::AsyncClient - brief overview here 

=cut

=head1 SYNOPSIS

synopsis here ...

=cut


=head1 DESCRIPTION

This modules' description here.

=cut

=head1 AUTHORS

 Edward Kawas (edward.kawas [at] gmail [dot] com)

=cut

#-----------------------------------------------------------------

=head1 SUBROUTINES

=cut

=head2 new

Creates a new AsyncClient object.

You can pass in a reference to MOBY::Client::ServiceInstance to initialize
the client, or nothing at all. 

=cut

#-----------------------------------------------------------------
# new
#-----------------------------------------------------------------
sub new {
	my ($class, $params) = @_;

	# create an object
	my $self = bless {}, ref($class) || $class;
	
	my $proceed = ref($params) =~ m/^MOBY::Client::ServiceInstance/;

	# set object data ... 
	$self->service( $proceed ?  $params->name : "" );
	$self->url( $proceed ?  $params->URL : "" );
	
	# done
	return $self;
}

=head2 execute

Calls the service asynchronously with the given scalar input and returns the output.
This sub may 'die', so its best to wrap a call to execute() in an eval and check $@
for any errors.

=cut

#-----------------------------------------------------------------
# execute
#-----------------------------------------------------------------
sub execute {
	my ($self, $input) = @_;
	
	# call a service using async soap
	# append '_submit' to the name 
	my $service = $self->service . "_submit";

	# set up the wsrf call
	my $soap = WSRF::Lite->proxy($self->url)->uri($WSRF::Constants::MOBY)->on_fault(
		sub {
			my $soap = shift;
			my $res  = shift;
			my $msg =
			  ref $res
			  ? "--- SOAP FAULT ---\n"
			  . $res->faultcode . " "
			  . $res->faultstring
			  ."--- SOAP FAULT ---\n"
			  : "--- TRANSPORT ERROR ---\n"
			  . $soap->transport->status
			  . "\n$res\n"
			  . "--- TRANSPORT ERROR ---\n";
			  
			die $msg;
		}
	);

	# extract all of the query ids from $input
	my @query_ids = $self->_get_query_ids($input);
	print "\nSending the following data to $service asynchronously:\n",
	  $input, "\n"
	  if $self->debug;

	# submit the job
	my $epr =
	  ( $soap->$service( SOAP::Data->type( 'string' => "$input" ) )->result );

	# Get address from the returned Endpoint Reference
	my $address = $epr->{'EndpointReference'}->{Address};

	# Get resource identifier from the returned Endpoint Reference
	my $identifier =
	  $epr->{'EndpointReference'}->{ReferenceParameters}->{ServiceInvocationId};

	# Compose the Endpoint Reference
	my $EPR = WSRF::WS_Address->new();
	$EPR->Address($address);
	$EPR->ReferenceParameters(   '<mobyws:ServiceInvocationId xmlns:mobyws="'
							   . $WSRF::Constants::MOBY . '">'
							   . $identifier
							   . '</mobyws:ServiceInvocationId>' );
	my %completed = ();
	while (1) {
		foreach my $queryID (@query_ids) {

			# skip poll if current job completed
			next if $completed{$queryID};

			# poll the service for given query ID
			my $searchTerm = "";
			$searchTerm .=
"<wsrp:ResourceProperty xmlns:wsrp='$WSRF::Constants::WSRP' xmlns:mobyws='$WSRF::Constants::MOBY'>";
			$searchTerm .= "mobyws:status_" . $queryID;
			$searchTerm .= "</wsrp:ResourceProperty>";

			$soap = WSRF::Lite->uri($WSRF::Constants::WSRP)->on_action(
				sub {
					sprintf '%s/%s/%sRequest', $WSRF::Constants::WSRPW, $_[1],
					  $_[1];
				}
			  )->wsaddress($EPR)
			  ->GetMultipleResourceProperties(
								  SOAP::Data->value($searchTerm)->type('xml') );

			my $parser = XML::LibXML->new();
			my $xml    = $soap->raw_xml;
			my $doc    = $parser->parse_string($xml);
			$soap = $doc->getDocumentElement();
			my $prop_name = "status_" . $queryID;

			my ($prop) =
			  $soap->getElementsByTagNameNS( $WSRF::Constants::MOBY,
											 $prop_name )
			  || $soap->getElementsByTagName($prop_name);
			my $event = $prop->getFirstChild->toString
			  unless ref $prop eq "XML::LibXML::NodeList";
			$event = $prop->pop()->getFirstChild->toString
			  if ref $prop eq "XML::LibXML::NodeList";

			my $status = LSAE::AnalysisEventBlock->new($event);
			if ( $status->type == LSAE_PERCENT_PROGRESS_EVENT ) {
				if ( $status->percentage >= 100 ) {
					$completed{$queryID} = 1;
				} elsif ( $status->percentage < 100 ) {
					print "Current percentage: ", $status->percentage, "\n" if $self->debug;
					sleep(20);
				} else {
					die "ERROR:  analysis event block not well formed.\n";
				}

			} elsif ( $status->type == LSAE_STATE_CHANGED_EVENT ) {
				if (    ( $status->new_state =~ m"completed"i )
					 || ( $status->new_state =~ m"terminated_by_request"i )
					 || ( $status->new_state =~ m"terminated_by_error"i ) )
				{
					$completed{$queryID} = 1;
				} elsif (    ( $status->new_state =~ m"created"i )
						  || ( $status->new_state =~ m"running"i ) )
				{
					print "Current State: ", $status->new_state, "\n" if $self->debug;
					sleep(20);
				} else {
					die "ERROR:  analysis event block not well formed.\n";
				}

			} elsif ( $status->type == LSAE_STEP_PROGRESS_EVENT ) {
				if ( $status->steps_completed >= $status->total_steps ) {
					$completed{$queryID} = 1;
				} elsif ( $status->steps_completed < $status->total_steps ) {
					print "Steps completed: ", $status->steps_completed, "\n" if $self->debug;
					sleep(20);
				} else {
					die "ERROR:  analysis event block not well formed.\n";
				}

			} elsif ( $status->type == LSAE_TIME_PROGRESS_EVENT ) {
				if ( $status->remaining == 0 ) {
					$completed{$queryID} = 1;
				} elsif ( $status->remaining > 0 ) {
					print "Time remaining: ", $status->remaining, "\n" if $self->debug;
					sleep(20);
				} else {
					die "ERROR:  analysis event block not well formed.\n";
				}
			}
		}
		last if scalar keys(%completed) == $#query_ids + 1;
	}

	my %results;
	foreach my $queryID (@query_ids) {
		# get the result
		my $searchTerm .=
"<wsrp:ResourceProperty xmlns:wsrp='$WSRF::Constants::WSRP' xmlns:mobyws='$WSRF::Constants::MOBY'>";
		$searchTerm .= "mobyws:result_" . $queryID;
		$searchTerm .= "</wsrp:ResourceProperty>";
		my $ans = WSRF::Lite->uri($WSRF::Constants::WSRP)->on_action(
			sub {
				sprintf '%s/%s/%sRequest', $WSRF::Constants::WSRPW, $_[1],
				  $_[1];
			}
		  )->wsaddress($EPR)
		  ->GetMultipleResourceProperties(
								  SOAP::Data->value($searchTerm)->type('xml') );
		die "ERROR:  " . $ans->faultstring if ( $ans->fault );

		my $parser = XML::LibXML->new();
		my $xml    = $ans->raw_xml;
		my $doc = $parser->parse_string($xml);
		$soap = $doc->getDocumentElement();
		my $prop_name = "result_" . $queryID;
		my ($prop) =
		     $soap->getElementsByTagNameNS( $WSRF::Constants::MOBY, $prop_name )
		  || $soap->getElementsByTagName($prop_name);
		my $result = $prop->getFirstChild->toString
		  unless ref $prop eq "XML::LibXML::NodeList";
		$result = $prop->pop()->getFirstChild->toString
		  if ref $prop eq "XML::LibXML::NodeList";
		$results{$queryID} = $result;
	}

	# destroy the result
	my $ans = WSRF::Lite->uri($WSRF::Constants::WSRL)->on_action(
		sub {
			sprintf '%s/ImmediateResourceTermination/%sRequest',
			  $WSRF::Constants::WSRLW, $_[1];
		}
	)->wsaddress($EPR)->Destroy();
	
	# merge the results back into a single XML file
	my $main_doc = undef;
	my $parent_node = undef;
	foreach my $id (keys %results) {
		my $parser = XML::LibXML->new();
		my $doc = $parser->parse_string($results{$id});
		unless ($main_doc) {
			$main_doc = $doc;
			my $mc = $main_doc->getElementsByLocalName("mobyContent");
			$main_doc = undef unless $mc->size() == 1;
			$parent_node = $mc->get_node(1) if $main_doc;
			next;
		}
		
		my $iterator  = $doc->getElementsByLocalName("mobyData");
		for ( 1 .. $iterator->size() ) {
			my $node = $iterator->get_node($_);
			$parent_node->appendChild($node);
		}
	}
	return $main_doc->toString(0);
	
}

=head2 service

Get/set the name of the service to execute 

=cut

#-----------------------------------------------------------------
# service
#-----------------------------------------------------------------
sub service {
	my ($self, $service) = @_;
	# getter
	return $self->{service} unless $service;
	# trim whitespace
	$service =~ s/^\s+//;
	$service =~ s/\s+$//;
	# setter
	$self->{service} = $service;
	# return the value that we set
	return $service;
}
=head2 url

Get/set the url endpoint of the service that we are interested in 

=cut

#-----------------------------------------------------------------
# url
#-----------------------------------------------------------------
sub url {
	my ($self, $url) = @_;
	# getter
	return $self->{url} unless $url;
	# trim whitespace
	$url =~ s/^\s+//;
	$url =~ s/\s+$//;
	# setter
	$self->{url} = $url;
	# return the value that we set
	return $url;
}

=head2 debug

Returns a true value if debugging has been turned on, and a false value otherwise.

The variable B<$MOBY::Client::AsyncClient::Constants::DEBUG> controls debugging. 

=cut

sub debug {
	return $MOBY::Client::AsyncClient::Constants::DEBUG;
}

sub _get_query_ids {
	my ($self, $input) = @_;
	my @query_ids = ();
	my $parser    = XML::LibXML->new();
	my $doc       = $parser->parse_string($input);
	my $iterator  = $doc->getElementsByLocalName("mobyData");
	for ( 1 .. $iterator->size() ) {
		my $node = $iterator->get_node($_);
		my $id   = $node->getAttribute("queryID")
		  || $node->getAttribute(
				 $node->lookupNamespacePrefix($WSRF::Constants::MOBY_MESSAGE_NS)
				   . ":queryID" );
		push @query_ids, $id;
	}
	return @query_ids;
}

1;
__END__
