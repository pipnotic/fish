# -=FISH Version 0.2=-
# Contact: Sarid Harper, saridski@yahoo.dk
# Written: 01.2006

# Please send any questions or comments to the address above
# Feel free to do what ever you wish with this programme and its code

# Install XML-XPath before using this programme, if running it with the 
# Perl interpreter
 
package fish;
	use strict;
	use XML::XPath;
	use Digest::MD5 qw(md5_hex);
	use Digest::SHA1 qw(sha1_hex);
	use Time::HiRes qw(gettimeofday);
	use configuration;

	# ----------------------------------------------	
	# PUBLIC MEMBERS
	# ----------------------------------------------	
	sub fish::begin($) {
		# This is the main worker public member
		my $self = shift;

		my $start = gettimeofday();
		
		print "\n-=FISH Version 0.2 Beta=-\n(F)ile\n(I)ntegrity tool by\n(S)arid\n(H)arper (sharpe)\n(!)FISH three times a week!\n";
		print "\n- Performing analysis.. ";
		$self->_walkfs($self->{'configuration'}->top());
		print "Complete.\n";
		print "- Generating database (".$self->{'configuration'}->output().").. ";
		$self->_createdatabase();
		print "Complete.\n";
		
		if ((keys %{$self->{'log'}}) > 0) {
			print "- Writing error log.. ";
			$self->_writeerrorlog();
			print "Complete.\n";
		}
		
		if (-e $self->{'configuration'}->sigdb()) {
			$self->comparefiles($start);
		}
	}
	
	sub fish::comparefiles($$) {
		# This public member is called when a user whishes to compare an older (known good)
		# signature database with the current system files
		my $self = shift;
		my $start = shift;
		
		print "- Reading database (".$self->{'configuration'}->sigdb().").. ";
		$self->_comparefiles($self->{'configuration'}->sigdb());
		print "Complete.\n";
		
		print "- Identifying deleted files.. ";
		$self->_findnewfiles();
		print "Complete.\n";
		
		print "- Identifying new files.. ";
		$self->_finddeletedfiles();			
		print "Complete.\n";
		
		print "- Writing results (".$self->{'configuration'}->report().").. ";
		$self->_createreport($self->{'configuration'}->report());	
		print "Complete.\n";

		print "\n- Summary:\n";
		print "  - Altered Files: ".(keys %{$self->{'alteredfiles'}})."\n";
		print "  - New files: ".(keys %{$self->{'newfiles'}})."\n";
		print "  - Deleted files: ".(keys %{$self->{'deletedfiles'}})."\n";
		print "  - Execution time: < ". int(((gettimeofday()-$start)/60)+1) ." minute(s).\n";
	}

	sub fish::NEW($$) {
		# Constructor
		my $proto = shift;
		my $class = ref($proto) || $proto;
		my $self  = {};	
		
		$self->{'configuration'} = configuration->NEW(shift);
		$self->{'top'} = undef;	
		$self->{'xmldb'} = undef;
		$self->{'hash'} = undef;
		$self->{'filetypes'} = ();
		$self->{'log'} = undef;
		$self->{'currentfiles'} = ();
		$self->{'alteredfiles'} = ();
		$self->{'dbfiles'} = ();	
		$self->{'newfiles'} = ();
		$self->{'deletedfiles'} = ();
		$self->{'count'} = 0;
		
		bless ($self, $class);
		return $self;
	}
	
	sub fish::DESTROY($) {
		# Destructor
		my $self = shift;
		
		$self->{'configuration'} = undef;
		$self->{'top'} = undef;	
		$self->{'xmldb'} = undef;
		$self->{'hash'} = undef;
		$self->{'filetypes'} = undef;
		$self->{'log'} = undef;
		$self->{'currentfiles'} = undef;
		$self->{'alteredfiles'} = undef;
		$self->{'dbfiles'} = undef;	
		$self->{'newfiles'} = undef;
		$self->{'deletedfiles'} = undef;
		$self->{'count'} = undef;
	}	
	
	# ----------------------------------------------	
	# PRIVATE MEMBERS
	# ----------------------------------------------
	sub fish::_denyrules($$) {
		my $self = shift;
		my $dirname = shift;
		
		foreach (@{$self->{'configuration'}->denyrules()}) {
			if ($dirname =~ m/$_/sig) {
				return(1);
			}
		}
		return(undef);
	}
	
	sub fish::_walkfs($$) { 
		# This private member iterates the file system recursively
		my $self = shift;
		my $top = shift;
		my $dir = undef;

		if (-d $top) {
			my $file = undef;
			if (opendir($dir, $top)) {
				while ($file = readdir($dir)) {
					next if ($file eq '.' || $file eq '..');
					next if ($self->_denyrules($top.'/'.$file));
					if (-f $top.'/'.$file) {
						foreach my $ext (@{$self->{'configuration'}->filetypes()}) {
							# Removed \. to enable the hashing of all files when no extension is given
							if ($file =~ /$ext$/i) {
								$self->{'count'}++;
								$self->{'currentfiles'}->{$top.'/'.$file} = $self->_computehash($top.'/'.$file);
								last;
							}
						}
					} else {
						$self->_walkfs($top.'/'.$file);
					}
				}
			}
		}
	}		
	
	sub fish::_computehash($$) {
		# Very basic stuff here..		
		# Opens file name passed to this private method
		# and calculates either a MD5 or SHA1 hash of its contents
		my $self = shift;
		my $file = shift;
		my $contents = "";

		open(F_DATA, "<", $file) || $self->_log($file, $!);
		while (<F_DATA>) {
			$contents .= $_;
		}
		#my $contents = do { local $/; <F_DATA> }; 
		close(F_DATA);
		
		if ($self->{'hash'} eq "MD5") {
			return Digest::MD5->md5_hex($contents)
		} else {
			return Digest::SHA1->sha1_hex($contents)
		}
	}	
	
	sub fish::_createdatabase($) {
		# Creates an XML database containing the signatures of all the included files
		# This file should be stored in a secure place, as it contains the file signatures
		my $self = shift;
		
		open(F_OUT, ">", ($self->{'configuration'}->output())) || die($!);
		print(F_OUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n});
		print(F_OUT qq{<signatures>\n});
		print(F_OUT qq{<session>\n});
		print(F_OUT qq{<created><![CDATA[}.localtime(time()).qq{]]></created>\n});
		print(F_OUT qq{<denyrules>\n});
		foreach (@{$self->{'configuration'}->denyrules()}) {
			print(F_OUT qq{<rule><![CDATA[$_]]></rule>\n});
		}
		print(F_OUT qq{</denyrules>\n});
		print(F_OUT qq{<rootdir><![CDATA[}.$self->{'configuration'}->top().qq{]]></rootdir>\n});
		print(F_OUT qq{<filetypes><![CDATA[}.join(":", @{$self->{'configuration'}->filetypes()}).qq{]]></filetypes>\n});
		print(F_OUT qq{<hash><![CDATA[}.$self->{'configuration'}->hash().qq{]]></hash>\n});
		print(F_OUT qq{<filecount><![CDATA[}.$self->{'count'}.qq{]]></filecount>\n});
		print(F_OUT qq{</session>\n});
		foreach (keys %{$self->{'currentfiles'}}) {
			print(F_OUT qq{\t<signature hash="$self->{'currentfiles'}->{$_}"><![CDATA[$_]]></signature>\n});
		}
		print(F_OUT qq{</signatures>\n});
		close(F_OUT);
	}

	sub fish::_comparefiles($$) {
		# Opens the signature database (the xml file generated by the method above)
		# Iterates through it and compared the the hash value in the signature data
		# with the hash just generated, which is located in this package's private member
		# called $self->{'currentfiles'}
		my $self = shift;
		my $database = shift;
		
		if (-e $database) {
			my $xpath = XML::XPath->new(filename => $database) || print($!);
			my $nodeset = $xpath->find('//signatures/signature');
			if ($self->{'currentfiles'}) {
				foreach ($nodeset->get_nodelist) {
					my $file = $_->string_value;
					my $hash = $_->find('@hash')->string_value;
					if (exists($self->{'currentfiles'}->{$file})) {
						if (($self->{'currentfiles'}->{$file}) ne ($hash)) {
							$self->{'alteredfiles'}->{$file} = $hash;
						}
					}
					$self->{'dbfiles'}->{$file} = $hash;
				}
			} else {					
				die("Please calculate file signatures first.\n");
			}
		} else {
			print("Failed\nThe specified file signature database does not exist.. Aborting.\n");
			exit();
		}
	}		
	
	sub fish::_findnewfiles($) {
		# Looks for new files
		# If a file exists on disk but not in the signature database then it is new
		# The results are stored in the private member $self->{'newfiles'}
		my $self = shift;
		my $key = undef;

		foreach (keys %{$self->{'currentfiles'}}) {
			if (!(exists($self->{'dbfiles'}->{$_}))) {
				$self->{'newfiles'}->{$_} = undef;
			}
		}
	}
	
	sub fish::_finddeletedfiles($) {
		# Looks for deleted files
		# If a file exists in the database but not on disk then it has been deleted
		# The results are stored in the private member $self->{'deletedfiles'}		
		my $self = shift;

		foreach (keys %{$self->{'dbfiles'}}) {
			if (!(exists($self->{'currentfiles'}->{$_}))) {
				$self->{'deletedfiles'}->{$_} = undef;
			}
		}
	}	
	
	sub fish::_createreport($$) {
		# Creates an xml report and stores the integrity scan results
		my $self = shift;
		my $file = shift;
		
		open(F_OUT, ">", $file) || die($!);
		print(F_OUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n});
		print(F_OUT qq{<changes>\n});
		print(F_OUT qq{<session>\n});
		print(F_OUT qq{<created><![CDATA[}.localtime(time()).qq{]]></created>\n});
		print(F_OUT qq{<denyrules>\n});
		foreach (@{$self->{'configuration'}->denyrules()}) {
			print(F_OUT qq{<rule><![CDATA[$_]]></rule>\n});
		}
		print(F_OUT qq{</denyrules>\n});
		
		print(F_OUT qq{<filetypes><![CDATA[}.join(":", @{$self->{'configuration'}->filetypes()}).qq{]]></filetypes>\n});
		print(F_OUT qq{<hash><![CDATA[}.$self->{'configuration'}->hash().qq{]]></hash>\n});
		print(F_OUT qq{</session>\n});
		print(F_OUT qq{<alteredfiles count="}.(keys %{$self->{'alteredfiles'}}).qq{">\n});
		foreach (keys %{$self->{'alteredfiles'}}) {
			print(F_OUT qq{\t\t<alteredfile newhash="$self->{'alteredfiles'}->{$_}" oldhash="$self->{'currentfiles'}->{$_}"><![CDATA[$_]]></alteredfile>\n});
		}
		print(F_OUT qq{\t</alteredfiles>\n});
		print(F_OUT qq{\t<newfiles count="}.(keys %{$self->{'newfiles'}}).qq{">\n});
		foreach (keys %{$self->{'newfiles'}}) {
			print(F_OUT qq{\t\t<newfile><![CDATA[$_]]></newfile>\n});
		}		
		print(F_OUT qq{\t</newfiles>\n});
		print(F_OUT qq{\t<deletedfiles count="}.(keys %{$self->{'deletedfiles'}}).qq{">\n});
		foreach (keys %{$self->{'deletedfiles'}}) {
			print(F_OUT qq{\t\t<deletedfile><![CDATA[$_]]></deletedfile>\n});
		}		
		print(F_OUT qq{\t</deletedfiles>\n});		
		print(F_OUT qq{</changes>\n});		
		close(F_OUT);		
	}	
	
	sub fish::_log($$$) {
		# Any errors are written to private member $self->{'log'}
		my $self = shift;
		my $file = shift;
		my $error = shift;
		
		$self->{'log'}->{$file} = $error;
		next;
	}
	
	sub fish::_writeerrorlog($) {
		# Private member $self->{'log'}, if it is !undef is written to an
		# xml file
		my $self = shift;
		
		open(F_OUT, ">", $self->{'configuration'}->errors()) || die($!);
		print(F_OUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n});
		print(F_OUT qq{<errors count="}.(keys %{$self->{'log'}}).qq{" created="}.localtime(time()).qq{">\n});

		foreach (keys %{$self->{'log'}}) {
			print(F_OUT qq{\t<error file="$_" error="$self->{'log'}->{$_}" />\n});
		}
		
		print(F_OUT "<\/errors>\n");	
		close(F_OUT);			
	}

1;
