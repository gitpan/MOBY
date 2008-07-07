	# Load the Module::Install bundled in ./inc/
	use inc::Module::Install;

	# Define metadata
	name 'MOBY';
	version '1.05';
	license 'perl';
	abstract
'This distribution is for communicating with or creating your own MOBY Central registry';
	all_from 'lib/MOBY/Central.pm';

	# Specific dependencies
	requires 'Carp'                => '0';
	requires 'File::Spec'          => '0.80';
	requires 'SOAP::Lite'          => '0.69';
	requires 'XML::LibXML'         => '1.62';
	requires 'IO::Stringy'         => '2.110';
	requires 'Unicode::String'     => '2.09';
	requires 'File::ShareDir'      => '0.05';
	requires 'Template'            => '0';
	requires 'Class::Inspector'    => '1.17';
	requires 'RDF::Core'           => '0.51';
	requires 'XML::XPath'          => '1.12';
	requires 'Text::Shellwords'    => '1.00';
	requires 'HTML::Entities'      => '0.01';
	requires 'LS'                  => '1.1.7';
	requires 'DBI'                 => '0.01';
	requires 'DBD::mysql'          => '0.01';

	if ( not( $^O =~ /MSWin32|Windows_NT/i ) ) {

		# non portable requires
		requires 'Want'           => '0';
		requires 'IO::Prompt'     => '0.99.2';
		requires 'IPC::Shareable' => '0.6';

		# check for WSRF
		eval "require WSRF::Lite";
		if ($@) {

			# WSRF not installed ... tell them where to get it
			print STDOUT <<'END_OF_TEXT';

################### IMPORTANT ###################

	WSRF lite is not installed on your system.
	Unfortunately, at this time, this Makefile
	cannot automatically find and install it for
	you. You will have to install it manually.
	
	The last known URL of where you could find
	this package is @
	http://www.rcs.manchester.ac.uk/research/wsrflite
	
	If that url does not exist, please search with
	google using the phrase 'WSRF-Lite'. 

	Sorry for any inconvenience caused!

##################################################

END_OF_TEXT

		}

		# MOBY::Async requires
		requires 'WSRF::Lite'               => '0.008.2.2';
		requires 'XML::DOM'                 => '';
		requires 'DateTime::Format::Epoch'  => '';
		requires 'DateTime::Format::W3CDTF' => '';
		requires 'HTTP::Daemon'             => '';
		requires 'HTTP::Daemon::SSL'        => '';
		requires 'MIME::Base64'             => '';
		requires 'Digest::SHA1'             => '';
		requires 'Crypt::OpenSSL::RSA'      => '';
		requires 'XML::CanonicalizeXML'     => '0.02';
		requires 'Sys::Hostname::Long'      => '';
		requires 'Crypt::OpenSSL::X509'     => '0';

	} else {
		print STDOUT <<'END_OF_TEXT';
			
################### IMPORTANT ###################

	Windows is not a suitable platform for those 
	wishing to maintain a registry that supports
	asynchronous services due to the lack of
	support for that platform of some of the 
	required libraries.
	
	The libraries in question are as follows:
		IPC::Shareable, IO::Prompt, 
		WSRF-Lite, & Crypt-OpenSSL-X509.
	
	Sorry for any inconvenience caused!
	
##################################################

END_OF_TEXT

	}

	build_requires 'Test::More'   => '0.42';
	build_requires 'Test::Simple' => '0.44';

	no_index 'directory' => 'bin/scripts';

	install_script 'bin/scripts/moby-s-install.pl';
	install_script 'bin/scripts/moby-s-caching.pl';

	install_share 'share';

	auto_install;
	WriteAll;

