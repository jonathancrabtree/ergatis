#!/local/perl/bin/perl


=head1  NAME 

MSF2Bsml.pl  - convert MSF format alignment files into BSML documents

=head1 SYNOPSIS

USAGE:  MSF2Bsml.pl -a ali_dir -o msf.bsml

=head1 OPTIONS

=over 4

=item *

B<--ali_dir,-a>   [REQUIRED] Dir containing MSF format alignment files that ends in *.msf

=item *

B<--output,-o> [REQUIRED] output BSML file

=item *

B<--suffix,-s> suffix of the multiple sequence alignment file. Default(msf)

=item *

B<--help,-h> This help message

=back

=head1   DESCRIPTION

MSF2Bsml.pl is designed to convert multiple sequence alignments in MSF format
into BSML documents.  As an option, the user can specify the suffix of the 
alignment files that the script should parse in the directory specified by 
--ali_dir.  The default suffix is "msf" i.e. family.msf.

Samples:

1. Convert all MFS formatted files that end in "aln" in ali_dir
   MSF2Bsml.pl -a ali_dir -o alignment.bsml -s aln


NOTE:  

Calling the script name with NO flags/options or --help will display the syntax requirement.


=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use BSML::BsmlBuilder;
use File::Basename;
use Pod::Usage;

my %options = ();
my $results = GetOptions (\%options, 'ali_dir|a=s', 'output|o=s', 'verbose|v', 'suffix|s=s', 'help|h', 'man') || pod2usage();

###-------------PROCESSING COMMAND LINE OPTIONS-------------###

my $output    = $options{'output'};
my $ali_dir   = $options{'ali_dir'};
$ali_dir =~ s/\/+$//;
my $msf_suffix = $options{'suffix'} || "msf";  #default suffix pattern of alignment files

&cmd_check();
###-------------------------------------------------------###


my $builder = new BSML::BsmlBuilder;

# add an analysis object to the document. 

$builder->createAndAddAnalysis( 'source_name' => $output,
				'program_version' => '1.0',
				'program' => 'clustal',
				'bsml_link_url' => 'BsmlTables',
				'bsml_link_relation' => 'MULTIPLE_ALIGNMENTS' );

my $file_found = 0;
opendir(DIR, $ali_dir) or die "Unable to access $ali_dir due to $!";
while( my $file = readdir(DIR)) {
    next if ($file =~ /^\.{1,2}$/);  #skip  "." ,  ".."
    if($file =~ /^(.+)\.$msf_suffix$/o) {
	$file_found++;
	my $fam_name = $1;
	my $MSF_alignments = process_MSF_file("$ali_dir/$file");
	next if(keys %$MSF_alignments < 1);   #skip empty msf files
	my $table = $builder->createAndAddMultipleAlignmentTable('molecule-type' => $MSF_alignments->{'mol_type'});
	my $summary = $builder->createAndAddAlignmentSummary( 'multipleAlignmentTable' => $table,
							      'seq-type' =>  $MSF_alignments->{'mol_type'},
							      'seq-format' => 'msf' 
							      );
	my $aln = $builder->createAndAddSequenceAlignment( 'multipleAlignmentTable' => $table );
	my $seqnum=0;
	my $sequences_tag;
	foreach my $seq (keys %{ $MSF_alignments->{'proteins'} }) {
	    $seqnum++;
	    my $alignment = join ('', @{ $MSF_alignments->{'proteins'}->{$seq}->{'alignment'} });
	    my $align_length = $MSF_alignments->{'proteins'}->{$seq}->{'length'};
	    $builder->createAndAddAlignedSequence( 'alignmentSummary' => $summary,
						   'seqnum' => $seqnum,
						   'length' => $align_length,
						   'name'   => $seq
                                                 );
	    $builder->createAndAddSequenceData( 'sequenceAlignment' => $aln,
						'seq-name' => $seq,
						'seq-data' => $alignment
                                              );
	    $sequences_tag .= "$seqnum:";
	}
	$aln->addattr( 'sequences', $sequences_tag );

    }

}

if($file_found) {
    $builder->write( $output );
    chmod 0755, $output;
} else {
    print STDERR "No files that ends in \"$msf_suffix\" are found in $ali_dir\n";
}




sub process_MSF_file {

    my $file = shift;


    my $MSF_alignments ={};
    open(MSF, "$file") or die "Unable to open $file due to $!";
    my $line;
    my $msf_type;
    while(defined($line = <MSF>) and $line !~ /^\/\//) {
	if( $line =~ /MSF:\s+([\S]+)\s+Type:\s+([\S]+)\s+Check/) {
	    my $msf_length = $1;
	    if($2 eq 'P') {
		$msf_type = 'protein';
	    }elsif($2 eq 'N') {
		$msf_type = 'nucleotide';
	    }else {
		$msf_type = 'protein';
	    }
	    $MSF_alignments->{'mol_type'} = $msf_type;
	}

	if($line =~ /Name:\s+([\S]+)\s+[o]{2}\s+Len:\s+([\S]+)\s+Check:\s+([\S]+)\s+Weight:\s+([\S]+)/) {
	    my $name    = $1;
	    my $ali_len = $2;
	    my $check   = $3;
	    my $weight  = $4;
	    
	    $MSF_alignments->{'proteins'}->{$name}->{'length'} = $ali_len;
	    $MSF_alignments->{'proteins'}->{$name}->{'check'}  = $check;
	    $MSF_alignments->{'proteins'}->{$name}->{'weight'} = $weight;
	    $MSF_alignments->{'proteins'}->{$name}->{'alignment'} = [];
	}
    }

    my $replacements;
    my $spaces;
    while($line = <MSF>) {
	if($line =~ /^([\S]+)/) {
	    my $name = $1;
	    if(exists($MSF_alignments->{'proteins'}->{$name})) {
		push( @{ $MSF_alignments->{'proteins'}->{$name}->{'alignment'} }, $line );
            } else {
		print STDERR "ERROR, $name is not valid protein name\n";
            }
	}
    }

    return $MSF_alignments;

}


sub cmd_check {
#quality check

    if( exists($options{'man'})) {
	pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }   

    if( exists($options{'help'})) {
	pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    if(!$output or !$ali_dir) {
	pod2usage({-exitval => 2,  -message => "$0: All the required options are not specified", -verbose => 1, -output => \*STDERR});
    }
    
    if(! -d $ali_dir) {
	print STDERR "$ali_dir directory NOT found.  Aborting...\n";
	exit 5;
    }

}	    





