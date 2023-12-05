# -=FISH Version 0.0.3 Beta=-
# (F)ile
# (I)ntegrity tool by
# (S)arid
# (H)arper (sharpe)
# (!)FISH three times a week!
 
package fish;
	use strict;
	use XML::XPath;
	use Time::localtime qw(ctime);
	use Digest::MD5 qw(md5_hex);
	use Digest::SHA1 qw(sha1_hex);
	use Time::HiRes qw(gettimeofday);
	use configuration;

	# Public Members
	sub NEW($$) {
		# Constructor
		my $proto = shift;
		my $class = ref($proto) || $proto;
		my $self  = {};	
		
		$self->{'configuration'} = configuration->NEW(shift);
		$self->{'files'} = ();
		$self->{'count'} = ();
		
		bless ($self, $class);
		return $self;
	}
	
	sub DESTROY($) {
		# Destructor
		my $self = shift;
		
		$self->{'configuration'} = undef;
		$self->{'files'} = undef;
		$self->{'count'} = undef;
	}
	
	sub begin($) {
		# This is the main worker public member
		my $self = shift;
		
		my $start = gettimeofday();
		
		print "\n-=FISH Version 0.0.3 Beta=-\n(F)ile\n(I)ntegrity tool by\n(S)arid\n(H)arper (sharpe)\n(!)FISH three times a week!\n";
		print "\n- Performing analysis.. ";
		$self->_walkfs($self->{'configuration'}->top());
		print "\n- Complete.\n\n";
		
		print "- Generating database (".$self->{'configuration'}->files->{'output'}.").. ";
		$self->_createDatabase();
		print "Complete.\n";
		
		if (-e $self->{'configuration'}->files->{'signatures'}) {
			$self->performAnalysis();
		}
		
		if (keys %{$self->{'files'}->{'log'}} > 0) {
			print "- Writing error log.. ";
			$self->_writeErrorLog();
			print "Complete.\n";
		}
		
		if (keys %{$self->{'files'}->{'skipped'}} > 0) {
			print "- Writing list over skipped files.. ";
			$self->_writeSkippedFiles();
			print "Done\n";
		}
		
		if (keys %{$self->{'files'}->{'unreadable'}} > 0) {
			print "- Writing list over unreadable files.. ";
			$self->_writeUnreadableFiles();
			print "Done\n";
		}
		
		print "\n- Summary:\n";
		print "  - Altered Files: ".(keys %{$self->{'files'}->{'altered'}})."\n";
		print "  - New files: ".(keys %{$self->{'files'}->{'new'}})."\n";
		print "  - Deleted files: ".(keys %{$self->{'files'}->{'deleted'}})."\n";
		print "  - Execution time: < ". int(((gettimeofday()-$start)/60)+1) ." minute(s).\n";
	}
	
	sub performAnalysis($) {
		# This public member is called when a user whishes to compare an older (known good)
		# signature database with the current system files
		my $self = shift;
		
		print "- Reading database (".$self->{'configuration'}->files->{'signatures'}.").. ";
		$self->_findAlteredFiles($self->{'configuration'}->files->{'signatures'});
		print "Complete.\n";
		
		print "- Identifying deleted files.. ";
		$self->_findNewFiles();
		print "Complete.\n";
		
		print "- Identifying new files.. ";
		$self->_findDeletedFiles();			
		print "Complete.\n";
		
		print "- Writing results (".$self->{'configuration'}->files->{'report'}.").. ";
		$self->_createReport($self->{'configuration'}->files->{'report'});	
		print "Complete.\n";
	}	
	
	# Private Members
	sub _walkfs($$) { 
		# This private member iterates the file system recursively
		my $self = shift;
		my $top = shift;
		my $dir = undef;

		if (-d $top) {
			my $file = undef;
			if (opendir $dir, $top) {
				while ($file = readdir $dir) {
					next if ($file eq '.' || $file eq '..');
					my $path = $top.'/'.$file;
					print "$path\n";
					# We have to do this check prior to the extension check, as this really
					# speeds things up (e.g. don't have to iterate through the valid extension types
					# until we find a valid one before having to check file sizes. We save lots of time here
					next if (int($self->_denyRules($path)) == 1);
					if (-f $path) {
						if (-r $path) {
							my $size = int(-s $path);
							if ($size/1024 < int($self->{'configuration'}->maxFilesize())) {
								foreach my $ext (@{$self->{'configuration'}->filetypes()}) {
									if ($path =~ /$ext$/i) {
										$self->{'count'}->{'files'}++;
										my ($mtime, $ctime) = (stat($path))[9,10];
										$self->{'files'}->{'current'}->{$path}->{'path'} = $path;
										$self->{'files'}->{'current'}->{$path}->{'hash'} = $self->_computeHash($top.'/'.$file);
										$self->{'files'}->{'current'}->{$path}->{'bytes'} = $size;
										$self->{'files'}->{'current'}->{$path}->{'kbytes'} = ($size/1024);
										$self->{'files'}->{'current'}->{$path}->{'mbytes'} = (($size/1024)/1024);
										$self->{'files'}->{'current'}->{$path}->{'mtime'} = ctime $mtime;
										$self->{'files'}->{'current'}->{$path}->{'ctime'} = ctime $ctime;
										last;
									} 
								} 
							} else {
								print "\n- [skipped:size] - $file (".int($size/1024)." kb)";
								$self->{'files'}->{'skipped'}->{$path}->{'size'} = int($size/1024);
							}
						} else {
							print "\n- [skipped:unreadable] - $file\n";
							$self->{'files'}->{'unreadable'}->{$path}->{'path'} = $path;
						}
					} else {
						# If we're here, then we must have a directory. Lets have a look in it
						$self->_walkfs($path);
					}
				}
			}
		}
	}

	sub _denyRules($$) {
		my $self = shift;
		my $dirname = shift;
		
		if ($@{$self->{'configuration'}->denyrules()} > 0) {
			foreach (@{$self->{'configuration'}->denyrules()}) {
				if ($dirname =~ m/$_/sig) {
					return 1;
				}
			}
		}
		return 0;
	}
	
	sub _computeHash($$) {
		my $self = shift;
		my $file = shift;
		
		#print "$file\n";
		my $function = undef;
		if ($self->{'hash'} eq "MD5") {
			$function = Digest::MD5->new;
		} else {
			$function = Digest::SHA1->new;
		}
		
		open FIN, "<", $file || $self->_logError($file, $!);		
		binmode FIN;
		
		eval {
			$function->addfile(*FIN);
		};
		
		close FIN;

		return $function->hexdigest;
	}	
	
	sub _createDatabase($) {
		# Creates an XML database containing the signatures of all the included files
		# This file should be stored in a secure place, as it contains the file signatures
		my $self = shift;
		
		open FOUT, ">", ($self->{'configuration'}->files->{'output'}) || die $!;
		print FOUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n};
		print FOUT qq{<fish>\n};
		print FOUT qq{\t<session date="}.localtime(time()).qq{" filetypes="}.join(":", @{$self->{'configuration'}->filetypes()}).qq{" hash="}.$self->{'configuration'}->hash().qq{" maxfilesize="}.$self->{'configuration'}->maxFilesize().qq{">\n};
		if ($@{$self->{'configuration'}->denyrules()} > 0) {
			print FOUT qq{\t\t<denyrules>\n};
			foreach (@{$self->{'configuration'}->denyrules()}) {
				print FOUT qq{\t\t\t<rule><![CDATA[$_]]></rule>\n};
			}
			print FOUT qq{\t\t</denyrules>\n};
		}
		print FOUT qq{\t\t<rootdir><![CDATA[}.$self->{'configuration'}->top().qq{]]></rootdir>\n};
		print FOUT qq{\t\t<files count="$self->{'count'}->{'files'}">\n};
		foreach (keys %{$self->{'files'}->{'current'}}) {
			my $temp = $self->{'files'}->{'current'}->{$_}->{'bytes'};
			print FOUT qq{\t\t\t<file hash="$self->{'files'}->{'current'}->{$_}->{'hash'}" bytes="$temp" kbytes="}.int($temp/1024).qq{" mbytes="}.(($temp/1024)/1024).qq{" mtime="$self->{'files'}->{'current'}->{$_}->{'mtime'}"><![CDATA[$self->{'files'}->{'current'}->{$_}->{'path'}]]></file>\n};
		}
		print FOUT qq{\t\t</files>\n};
		print FOUT qq{\t</session>\n};
		print FOUT qq{</fish>\n};
		close FOUT;
	}	
	
	sub _findAlteredFiles($$) {
		# Opens the signature database (the xml file generated by the method above)
		# Iterates through it and compared the the hash value in the signature data
		# with the hash just generated, which is located in this package's private member
		# called $self->{'files'}->{'current'}
		my $self = shift;
		my $database = shift;
		
		if (-e $database) {
			my $xpath = XML::XPath->new(filename => $database) || print $!;
			my $nodeset = $xpath->find('//files/file');
			
			foreach ($nodeset->get_nodelist) {	
				my $path = $_->string_value;
				my $oldhash = $_->find('@hash')->string_value;
				my ($size, $mtime, $ctime) = (stat $path)[7,9,10];
				if (exists($self->{'files'}->{'current'}->{$path})) {
					my $newhash = $self->{'files'}->{'current'}->{$path}->{'hash'};
					if ($newhash ne $oldhash) {
						$self->{'files'}->{'altered'}->{$path}->{'hash'} = $newhash;
						$self->{'files'}->{'altered'}->{$path}->{'bytes'} = $size;
						$self->{'files'}->{'altered'}->{$path}->{'kbytes'} = ($size/1024);;
						$self->{'files'}->{'altered'}->{$path}->{'mytes'} = (($size/1024)/1024);
						$self->{'files'}->{'altered'}->{$path}->{'mtime'} = ctime $mtime;
						$self->{'files'}->{'altered'}->{$path}->{'ctime'} = ctime $ctime;
					}
				}
				$self->{'files'}->{'database'}->{$path}->{'path'} = $path;
				$self->{'files'}->{'database'}->{$path}->{'hash'} = $oldhash;
				$self->{'files'}->{'database'}->{$path}->{'bytes'} = $_->find('@bytes')->string_value;
				$self->{'files'}->{'database'}->{$path}->{'kbytes'} = $_->find('@kbytes')->string_value;
				$self->{'files'}->{'database'}->{$path}->{'mbytes'} = $_->find('@mbytes')->string_value;
				$self->{'files'}->{'database'}->{$path}->{'mtime'} = $_->find('@mtime')->string_value;
				$self->{'files'}->{'database'}->{$path}->{'ctime'} = $_->find('@ctime')->string_value;
			}
		} else {
			print "Failed\nThe specified file signature database does not exist.. Aborting.\n";
			exit;
		}
	}
	
	sub _findNewFiles($) {
		# Looks for new files
		# If a file exists on disk but not in the signature database then it is new
		# The results are stored in the private member $self->{'newfiles'}
		my $self = shift;

		foreach (keys %{$self->{'files'}->{'current'}}) {
			if (!(exists($self->{'files'}->{'database'}->{$_}))) {
				my $bytes = (-s $_);
				$self->{'files'}->{'new'}->{$_}->{'bytes'} = $bytes;
				$self->{'files'}->{'new'}->{$_}->{'kbytes'} = ($bytes/1024);
				$self->{'files'}->{'new'}->{$_}->{'mbytes'} = (($bytes/1024)/1024);
				$self->{'files'}->{'new'}->{$_}->{'path'} = $self->{'files'}->{'current'}->{$_}->{'path'};
				$self->{'files'}->{'new'}->{$_}->{'mtime'} = $self->{'files'}->{'current'}->{$_}->{'mtime'};
				$self->{'files'}->{'new'}->{$_}->{'ctime'} = $self->{'files'}->{'current'}->{$_}->{'ctime'};
			}
		}
	}
	
	sub _findDeletedFiles($) {
		# Looks for deleted files
		# If a file exists in the database but not on disk then it has been deleted
		# The results are stored in the private member $self->{'deletedfiles'}		
		my $self = shift;

		foreach (keys %{$self->{'files'}->{'database'}}) {
			if (!(exists($self->{'files'}->{'current'}->{$_}))) {
				$self->{'files'}->{'deleted'}->{$_}->{'path'} = $self->{'files'}->{'database'}->{$_}->{'path'};
				$self->{'files'}->{'deleted'}->{$_}->{'hash'} = $self->{'files'}->{'database'}->{$_}->{'hash'};
			}
		}
	}	
	
	sub _createReport($$) {
		# Creates an xml report and stores the integrity scan results
		my $self = shift;
		my $file = shift;

		open FOUT, ">", $file || die$!;
		print FOUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n};
		print FOUT qq{<fish>\n};
		print FOUT qq{\t<session date="}.localtime(time()).qq{" filetypes="}.join(":", @{$self->{'configuration'}->filetypes()}).qq{" hash="}.$self->{'configuration'}->hash().qq{" maxfilesize="}.$self->{'configuration'}->maxFilesize().qq{">\n};

		if ($@{$self->{'configuration'}->denyrules()} > 0) {
			print FOUT qq{\t\t<denyrules>\n};
			foreach (@{$self->{'configuration'}->denyrules()}) {
				print FOUT qq{\t\t\t<rule><![CDATA[$_]]></rule>\n};
			}
			print FOUT qq{\t\t</denyrules>\n};
		}

		print FOUT "\t\t<files>\n";
		print FOUT qq{\t\t\t<altered count="}.(keys %{$self->{'files'}->{'altered'}}).qq{">\n};
		foreach (keys %{$self->{'files'}->{'altered'}}) {
			print FOUT qq{\t\t\t<file>\n};
			print FOUT qq{\t\t\t\t<path><![CDATA[$_]]></path>\n};
			
			print FOUT "\t\t\t\t\t<hash>\n";
			print FOUT qq{\t\t\t\t<old value="$self->{'files'}->{'database'}->{$_}->{'hash'}" />\n};
			print FOUT qq{\t\t\t\t<new value="$self->{'files'}->{'altered'}->{$_}->{'hash'}" />\n};
			print FOUT "\t\t\t\t\t</hash>\n";
			
			print FOUT "\t\t\t\t\t<mtime>\n";
			print FOUT qq{\t\t\t\t<old value="$self->{'files'}->{'database'}->{$_}->{'mtime'}" />\n};
			print FOUT qq{\t\t\t\t<new value="$self->{'files'}->{'altered'}->{$_}->{'mtime'}" />\n};
			print FOUT "\t\t\t\t\t</mtime>\n";
			
			print FOUT "\t\t\t\t\t<size>\n";
			print FOUT qq{\t\t\t\t<old value="$self->{'files'}->{'database'}->{$_}->{'kbytes'} kb" />\n};
			print FOUT qq{\t\t\t\t<new value="$self->{'files'}->{'altered'}->{$_}->{'kbytes'} kb" />\n};
			print FOUT "\t\t\t\t\t</size>\n";
		
			print FOUT qq{\t\t\t</file>\n};
		}
		print FOUT qq{\t\t\t</altered>\n};
		print FOUT qq{\t\t\t<new count="}.(keys %{$self->{'files'}->{'new'}}).qq{">\n};
		foreach (keys %{$self->{'files'}->{'new'}}) {
			my $temp = $self->{'files'}->{'new'}->{$_}->{'bytes'};
			print FOUT qq{\t\t\t\t<file ctime="$self->{'files'}->{'new'}->{$_}->{'ctime'}" mtime="$self->{'files'}->{'new'}->{$_}->{'mtime'}" bytes="$temp" kbytes="}.($temp/1024).qq{" mbytes="}.(($temp/1024)/1024).qq{"><![CDATA[$self->{'files'}->{'new'}->{$_}->{'path'}]]></file>\n};
		}		
		print FOUT qq{\t\t\t</new>\n};
		print FOUT qq{\t\t<deleted count="}.(keys %{$self->{'files'}->{'deleted'}}).qq{">\n};
		foreach (keys %{$self->{'files'}->{'deleted'}}) {
			print FOUT qq{\t\t\t<deleted hash="$self->{'files'}->{'deleted'}->{$_}->{'hash'}"><![CDATA[$self->{'files'}->{'deleted'}->{$_}->{'path'}]]></deleted>\n};
		}		
		print FOUT qq{\t\t</deleted>\n};
		print FOUT "\t</files>\n";
		print FOUT qq{\t</session>\n};
		print FOUT qq{</fish>\n};
		close FOUT;		
	}	
	
	sub _logError($$$) {
		# Any errors are written to private member $self->{'log'}
		my $self = shift;
		my $file = shift;
		my $error = shift;
		
		$self->{'files'}->{'log'}->{$file}->{'error'} = $error;
		last;
	}
	
	sub _writeSkippedFiles($) {
		my $self = shift;
		
		my $file = "skipped-files.xml";
		
		open FOUT, ">$file" || $self->_logError($file, $!);
		
		print FOUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n};
		my $count = keys %{$self->{'files'}->{'skipped'}};
		
		print FOUT qq{<skipped count="$count" reason="size">\n};
		
		foreach (keys %{$self->{'files'}->{'skipped'}}) {
			print FOUT qq{\t<file size="}.(int($self->{'files'}->{'skipped'}->{$_}->{'size'})/1024).qq{ kb"><![CDATA[}.$_.qq{]]></file>\n};
		}
		
		print FOUT qq{</skipped>\n};
		close FOUT;
	}
	
	sub _writeUnreadableFiles($) {
		my $self = shift;

		my $file = "unreadable-files.xml";
		
		open FOUT, ">$file" || $self->_logError($file, $!);
		
		print FOUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n};
		
		my $count = keys %{$self->{'files'}->{'unreadable'}};
		print FOUT qq{<unreadable count="$count" reason="unreadable">\n};
		
		foreach (keys %{$self->{'files'}->{'unreadable'}}) {
			print FOUT qq{\t<file><![CDATA[}.$_.qq{]]></file>\n};
		}
		
		print FOUT qq{\t</unreadable>\n};
		close FOUT;
	}
	
	sub _writeErrorLog($) {
		# Private member $self->{'log'}, if it is !undef is written to an
		# xml file
		my $self = shift;
		
		open FOUT, ">", $self->{'configuration'}->errors() || die$!;
		print FOUT qq{<?xml version="1.0" encoding="iso-8859-1"?>\n};
		print FOUT qq{<errors count="}.(keys %{$self->{'log'}}).qq{" created="}.localtime(time()).qq{" reason="unspecified">\n};

		foreach (keys %{$self->{'log'}}) {
			print FOUT qq{\t<error file="$_" error="$self->{'log'}->{$_}" />\n};
		}
		
		print FOUT "<\/errors>\n";	
		close FOUT;
	}

1;
