# -=FISH Version 0.0.4 Beta=-
# (F)ile
# (I)ntegrity tool by
# (S)arid
# (H)arper (sharpe)
# (!)FISH three times a week!
package configuration;
	sub NEW($) {	
		my $proto = shift;
		my $class = ref($proto) || $proto;
		my $self  = {};	
		
		$self->{'configfile'} = shift;
		$self->{'top'} = undef;
		$self->{'maxsize'} = undef;
		$self->{'files'} = ();
		$self->{'filetypes'} = ();
		$self->{'denyrules'} = ();
		
		bless ($self, $class);
		$self->_readconfig();
		return $self;
	}
	
	sub DESTROY($) {
		my $self = shift;
		
		$self->{'configfile'} = undef;
		$self->{'top'} = undef;
		$self->{'maxsize'} = undef;
		$self->{'files'} = undef;
		$self->{'filetypes'} = undef;
		$self->{'denyrules'} = undef;
	}

	sub top($) {
		my $self = shift;
		@_ ? $self->{'top'} = shift : $self->{'top'};
	}

	sub hash($) {
		my $self = shift;
		@_ ? $self->{'hash'} = shift : $self->{'hash'};
	}
	
	sub maxFilesize($) {
		my $self = shift;
		@_ ? $self->{'maxsize'} = shift : $self->{'maxsize'};
	}

	sub filetypes($) {
		my $self = shift;
		@_ ? $self->{'filetypes'} = shift : $self->{'filetypes'};
	}

	sub denyrules($) {
		my $self = shift;
		@_ ? $self->{'denyrules'} = shift : $self->{'denyrules'};
	}

	sub files($) {
		my $self = shift;
		@_ ? $self->{'files'} = shift : $self->{'files'};
	}	

	# ----------------------------------------------	
	# PRIVATE MEMBERS
	# ----------------------------------------------	
	sub _readconfig($) {
		my $self = shift;

		if (-e $self->{'configfile'}) {
			# Here we grab all the configuration parameters from the configuration file
			# Alterations to the configuration file should be reflected below
			my $xpath = XML::XPath->new(filename => $self->{'configfile'}) || print($!);
			$self->{'top'} = $xpath->find('//configuration/session/top');
			$self->{'hash'} = $xpath->find('//configuration/session/hash/@function');
			$self->{'maxsize'} = $xpath->find('//configuration/session/file/@maxsize');

			my $nodeset = $xpath->find('//configuration/session/extensions/extension');
			foreach my $node ($nodeset->get_nodelist) {
				push(@{$self->{'filetypes'}}, $node->find('@value')->string_value());
			}

			$nodeset = $xpath->find('//configuration/session/denyrules/rule');
			foreach my $node ($nodeset->get_nodelist) {
				push(@{$self->{'denyrules'}}, $node->string_value());
			}

			$self->{'files'}->{'output'} = $xpath->find('//configuration/files/output');
			$self->{'files'}->{'signatures'} = $xpath->find('//configuration/files/sigdb');
			$self->{'files'}->{'report'} = $xpath->find('//configuration/files/report');
			$self->{'files'}->{'errors'} = $xpath->find('//configuration/files/errors');

			$nodeset = undef;
			$xpath = undef;
		} else {
			die "\nThe file configuration file \'".$self->{'configfile'}."\' does not exist.. Aborting.\n";
		}
	}
1;