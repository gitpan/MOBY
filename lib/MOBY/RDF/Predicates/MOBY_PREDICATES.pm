package MOBY::RDF::Predicates::MOBY_PREDICATES;

use strict;

BEGIN {

	use constant MOBY_PREDICATES_PREFIX => 'moby';

	use constant MOBY_PREDICATES_URI =>
	  'http://biomoby.org/RESOURCES/MOBY-S/Predicates#';

######################################
## Predicates for MOBY_PREDICATES   ##
######################################

	use constant hasa        => MOBY_PREDICATES_URI . 'hasa';
	use constant has         => MOBY_PREDICATES_URI . 'has';
	use constant articleName => MOBY_PREDICATES_URI . 'articleName';

}
1;
