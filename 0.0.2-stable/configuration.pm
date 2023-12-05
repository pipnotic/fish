package configuration;
	use strict;

	# ----------------------------------------------	
	# PUBLIC MEMBERS
	# ----------------------------------------------
	sub configuration::NEW($) {	
		my $proto = shift;
		my $class = ref($proto) || $proto;
		my $self  = {};	
		
		$self->{'configfile'} = shift;
		$self->{'top'} = undef;
		$self->{'output'} = undef;
		$self->{'hash'} = undef;
		$self->{'hashdb'} = undef;
		$self->{'report'} = undef;
		$self->{'errors'} = undef;
		$self->{'filetypes'} = ();
		$self->{'denyrules'} = ();
		
		bless ($self, $class);
		$self->_readconfig();
		return $self;
	}
	
	sub service::DESTROY($) {
		my $self = shift;
		
		$self->{'configfile'} = undef;
		$self->{'top'} = undef;
		$self->{'output'} = undef;
		$self->{'hash'} = undef;
		$self->{'hashdb'} = undef;
		$self->{'report'} = undef;
		$self->{'errors'} = undef;
		$self->{'filetypes'} = undef;
		$self->{'denyrules'} = undef;	
	}

	sub configuration::top($) {
		my $self = shift;
		@_ ? $self->{'top'} = shift : $self->{'top'};
	}

	sub configuration::hash($) {
		my $self = shift;
		@_ ? $self->{'hash'} = shift : $self->{'hash'};
	}

	sub configuration::filetypes($) {
		my $self = shift;
		@_ ? $self->{'filetypes'} = shift : $self->{'filetypes'};
	}

	sub configuration::denyrules($) {
		my $self = shift;
		@_ ? $self->{'denyrules'} = shift : $self->{'denyrules'};
	}	

	sub configuration::output($) {
		my $self = shift;
		@_ ? $self->{'output'} = shift : $self->{'output'};
	}

	sub configuration::sigdb($) {
		my $self = shift;
		@_ ? $self->{'hashdb'} = shift : $self->{'hashdb'};
	}	

	sub configuration::report($) {
		my $self = shift;
		@_ ? $self->{'report'} = shift : $self->{'report'};
	}	

	sub configuration::errors($) {
		my $self = shift;
		@_ ? $self->{'errors'} = shift : $self->{'errors'};
	}	

	# ----------------------------------------------	
	# PRIVATE MEMBERS
	# ----------------------------------------------	
	sub configuration::_readconfig($) {
		my $self = shift;

		if (-e $self->{'configfile'}) {
			# Here we grab all the configuration parameters from the configuration file
			# Alterations to the configuration file should be reflected below
			my $xpath = XML::XPath->new(filename => $self->{'configfile'}) || print($!);
			$self->{'top'} = $xpath->find('//configuration/session/top');
			$self->{'hash'} = $xpath->find('//configuration/session/hash');

			my $nodeset = $xpath->find('//configuration/session/extensions/extension');
			foreach my $node ($nodeset->get_nodelist) {
				push(@{$self->{'filetypes'}}, $node->find('@value')->string_value());
			}

			$nodeset = $xpath->find('//configuration/session/denyrules/rule');
			foreach my $node ($nodeset->get_nodelist) {
				push(@{$self->{'denyrules'}}, $node->string_value());
			}

			$self->{'output'} = $xpath->find('//configuration/files/output');
			$self->{'hashdb'} = $xpath->find('//configuration/files/sigdb');
			$self->{'report'} = $xpath->find('//configuration/files/report');
			$self->{'errors'} = $xpath->find('//configuration/files/errors');

			$nodeset = undef;
			$xpath = undef;
		} else {
			die("\nThe file configuration file \'".$self->{'configfile'}."\' does not exist.. Aborting.\n");
		}
	}
1;