# -=FISH Version 0.2=-
# Contact: Sarid Harper, saridski@yahoo.dk
# Written: 01.2006

# Please send any questions or comments to the address above
# Feel free to do what ever you wish with this programme and its code

# Install XML-XPath before using this programme, if running it with the 
# Perl interpreter

package configuration;
	use strict;

	# ----------------------------------------------	
	# PUBLIC MEMBERS
	# ----------------------------------------------
	sub configuration::NEW($) {	
		my $proto = shift();
		my $class = ref($proto) || $proto;
		my $self  = {};	
		
		$self->{_CONFIGFILE} = shift();
		$self->{_TOP} = undef;
		$self->{_OUTPUT} = undef;
		$self->{_HASH} = undef;
		$self->{_SIGDB} = undef;
		$self->{_REPORT} = undef;
		$self->{_ERRORS} = undef;
		$self->{_FILETYPES} = ();
		$self->{_DENYRULES} = ();
		
		bless ($self, $class);
		$self->_readconfig();
		return $self;
	}
	
	sub service::DESTROY($) {
		my $self = shift();
		
		$self->{_CONFIGFILE} = undef;
		$self->{_TOP} = undef;
		$self->{_OUTPUT} = undef;
		$self->{_HASH} = undef;
		$self->{_SIGDB} = undef;
		$self->{_REPORT} = undef;
		$self->{_ERRORS} = undef;
		$self->{_FILETYPES} = undef;
		$self->{_DENYRULES} = undef;
	}

	sub configuration::top($) {
		my $self = shift();
		@_ ? $self->{_TOP} = shift() : $self->{_TOP};
	}

	sub configuration::hash($) {
		my $self = shift();
		@_ ? $self->{_HASH} = shift() : $self->{_HASH};
	}

	sub configuration::filetypes($) {
		my $self = shift();
		@_ ? $self->{_FILETYPES} = shift() : $self->{_FILETYPES};
	}

	sub configuration::denyrules($) {
		my $self = shift();
		@_ ? $self->{_DENYRULES} = shift() : $self->{_DENYRULES};
	}	

	sub configuration::output($) {
		my $self = shift();
		@_ ? $self->{_OUTPUT} = shift() : $self->{_OUTPUT};
	}

	sub configuration::sigdb($) {
		my $self = shift();
		@_ ? $self->{_SIGDB} = shift() : $self->{_SIGDB};
	}	

	sub configuration::report($) {
		my $self = shift();
		@_ ? $self->{_REPORT} = shift() : $self->{_REPORT};
	}	

	sub configuration::errors($) {
		my $self = shift();
		@_ ? $self->{_ERRORS} = shift() : $self->{_ERRORS};
	}	

	# ----------------------------------------------	
	# PRIVATE MEMBERS
	# ----------------------------------------------	
	sub configuration::_readconfig($) {
		my $self = shift();

		if (-e $self->{_CONFIGFILE}) {
			# Here we grab all the configuration parameters from the configuration file
			# Alterations to the configuration file should be reflected below
			my $xpath = XML::XPath->new(filename => $self->{_CONFIGFILE}) || print($!);
			$self->{_TOP} = $xpath->find('//configuration/session/top');
			$self->{_HASH} = $xpath->find('//configuration/session/hash');

			my $nodeset = $xpath->find('//configuration/session/extensions/extension');
			foreach my $node ($nodeset->get_nodelist) {
				push(@{$self->{_FILETYPES}}, $node->find('@value')->string_value());
			}

			my $nodeset = $xpath->find('//configuration/session/denyrules/rule');
			foreach my $node ($nodeset->get_nodelist) {
				push(@{$self->{_DENYRULES}}, $node->string_value());
			}

			$self->{_OUTPUT} = $xpath->find('//configuration/files/output');
			$self->{_SIGDB} = $xpath->find('//configuration/files/sigdb');
			$self->{_REPORT} = $xpath->find('//configuration/files/report');
			$self->{_ERRORS} = $xpath->find('//configuration/files/errors');

			$xpath = undef;
		} else {
			die("\nThe file configuration file \'".$self->{_CONFIGFILE}."\' does not exist.. Aborting.\n");
		}
	}
1;