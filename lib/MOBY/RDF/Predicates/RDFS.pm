package MOBY::RDF::Predicates::RDFS;

use strict;

BEGIN {

	use constant RDFS_PREFIX => 'rdfs';

	use constant RDFS_URI => 'http://www.w3.org/2000/01/rdf-schema#';

################################
## Predicates for RDFS        ##
################################

	use constant comment    =>  RDFS_URI . 'comment' ;
	use constant label      =>  RDFS_URI . 'label' ;
	use constant subClassOf =>  RDFS_URI . 'subClassOf' ;

}
1;
