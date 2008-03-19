#$Id: Serializer.pm,v 1.1 2008/02/21 00:21:28 kawas Exp $
package MOBY::SOAP::Serializer;

# this module serializes SOAP messages to ensure
# compatibility with other soap clients (Java)
# All that you have to do to make this your serializer,
# is to uncomment, from MOBY-Central.pl, the line:
#
# 	$x->serializer(MOBY::SOAP::Serializer->new);
#
# and all soap messages will pass through this serializer.
#
# 	MAKE SURE TO 'use MOBY::SOAP::Serializer;'
#
# This ensures that mobycentral is compatible with
# SOAP-lite version >= .6
@MOBY::SOAP::Serializer::ISA = 'SOAP::Serializer';

sub xmlize {
	my $self = shift;
	my ( $name, $attrs, $values, $id ) = @{ +shift };
	$attrs ||= {};

	# keep only namespace attributes for all elements
	my $a = $attrs->{xmlns} ? { xmlns => $attrs->{xmlns} } : {};

	return $self->SUPER::xmlize( [ $name, $a, $values, $id ] );
}    

sub envelope {

	delete $_[0]{_namespaces}->{'http://schemas.xmlsoap.org/soap/encoding/'}
	  if $_[0];

	# only 'transform' soap responses
	UNIVERSAL::isa( $_[3] => 'SOAP::Data' )
	  ? do {

# below encodes data
#my $xml = $_[3]->value;
#$xml =~ s"&"&amp;"g;
#$xml =~ s"\<"&lt;"g;
#$xml =~ s"\]\]\>"\]\]&gt;"g;
#$_[3]->value($xml);
# when we set to string, we dont have to encode
#FIXME - this wont work for the DUMP call if and when a SOAP::Data object is passed
		$_[3]->type( 'string' => $_[3]->value() );
	  }

	  : do {
		do {

			# for dumps, they are of type array: set them accordingly
			$_[3]->[0] = SOAP::Data->type( 'string' => $_[3]->[0] )
			  if $_[3]->[0];
			$_[3]->[1] = SOAP::Data->type( 'string' => $_[3]->[1] )
			  if $_[3]->[1];
			$_[3]->[2] = SOAP::Data->type( 'string' => $_[3]->[2] )
			  if $_[3]->[2];
			$_[3]->[3] = SOAP::Data->type( 'string' => $_[3]->[3] )
			  if $_[3]->[3];
			$_[3]->[4] = SOAP::Data->type( 'string' => $_[3]->[4] )
			  if $_[3]->[4];
		} if ( ref( $_[3] ) eq 'ARRAY' );
		do {

			# below encodes data -> set type to string and we dont have to
			#$_[3] =~ s"&"&amp;"g;
			#$_[3] =~ s"\<"&lt;"g;
			#$_[3] =~ s"\]\]\>"\]\]&gt;"g;
			# set to string to avoid encoding
			$_[3] = SOAP::Data->type( 'string' => $_[3] );
		} unless ( ref( $_[3] ) eq 'ARRAY' );
	  } if $_[1] =~ /^(?:method|response)$/;

	$_[2] = (
			  UNIVERSAL::isa( $_[2] => 'SOAP::Data' )
			  ? $_[2]
			  : SOAP::Data->name( $_[2] )->attr( { xmlns => $uri } )
	  )
	  if $_[1] =~ /^(?:method|response)$/;

	shift->SUPER::envelope(@_);
}

1;
