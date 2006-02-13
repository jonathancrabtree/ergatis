#!/usr/local/bin/perl -w

=head1  NAME 

delete_pipeline.pl - delete a workflow pipeline and, optionally, its output data

=head1 SYNOPSIS

USAGE: delete_pipeline.pl 
        --pipeline_id=1234
        --repository_root=/usr/local/annotation/AA1
      [ --lock_file=/path/to/somefile.lock
        --delete_output=1
        --log=/path/to/some.log
      ]

=head1 OPTIONS

B<--pipeline_id,-i> 
    The ID of the pipeline to delete

B<--repository_root,-r> 
    The project directory, just under which we should find the asmbls directory.

B<--lock_file,-k> 
    optional.  This file will be created at the start of the run and will contain
    only the word "deleting".  Any existing file will get stomped.  It will be
    deleted once process is finished.

B<--delete_output,-o> 
    optional.  If passed, the output in the standard output directory structure
    for this pipeline will also be removed.

B<--log,-l> 
    optional.  will create a log file with summaries of all actions performed.

B<--help,-h> 
    This help message/documentation.

=head1   DESCRIPTION

This script is used to delete a pipeline and all its associated output.  This
is based on pipeline_id and repository root.  Deleted folders include (in order):

    $repository_root/Workflow/*/$pipelineid_*
    $repository_root/output_repository/*/$pipelineid_*
    $repository_root/Workflow/pipeline/$pipelineid


=head1 INPUT

The input is defined with the --repository_root and --pipeline_id options.

=head1 OUTPUT

This is a deletion script.  There is no output unless you use the --log option.

=head1 CONTACT

    Joshua Orvis
    jorvis@tigr.org

=cut

use strict;
use File::Find;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use IO::Handle;
use Pod::Usage;

my %options = ();
my $results = GetOptions (\%options, 
			  'pipeline_id|i=i',
              'repository_root|r=s',
              'lock_file|k=s',
              'delete_output|o=i',
              'log|l=s',
			  'help|h') || pod2usage();

# display documentation
if( $options{'help'} ){
    pod2usage( {-exitval=>0, -verbose => 2, -output => \*STDOUT} );
}

## play nicely
umask(0000);

## make sure all passed options are peachy
&check_parameters(\%options);

## create the lock file if requested
my $lockfh;
if ( $options{lock_file} ) {
    open($lockfh, ">$options{lock_file}") || die "failed to create lock file $options{lock_file}: $!";
    print $lockfh "deleting";
}

## open the log if requested
my $logfh;
if (defined $options{log}) {
    open($logfh, ">$options{log}") || die "can't create log file: $!";
    
    ## i'm setting autoflush here so that logs are written immediately
    ##  i was getting terrible lag otherwise.
    autoflush $logfh 1;
}

my $wf_dir = "$options{repository_root}/Workflow";
opendir( my $wfdh, $wf_dir );

## get the things in the workflow directory (except the pipeline)
_log("INFO: scanning $wf_dir");
for my $component ( readdir $wfdh ) {
    _log("INFO: scanning $wf_dir/$component");
    
    for my $rundir ( glob "$wf_dir/$component/$options{pipeline_id}_*" ) {
        _log("INFO: recursively removing $rundir");
        
        &find_remove($rundir);
    }
}

## the user can optionally delete the output repository too
if ( $options{delete_output} ) {
    my $o_dir  = "$options{repository_root}/output_repository";
    opendir( my $odh, $o_dir );

    for my $component ( readdir $odh ) {
        for my $rundir ( glob "$o_dir/$component/$options{pipeline_id}_*" ) {
            _log("INFO: recursively removing $rundir");

            &find_remove($rundir);
        }
    }
}

## delete the pipeline xml explicitly
_log("INFO: recursively removing $wf_dir/pipeline/$options{pipeline_id}");
&find_remove("$wf_dir/pipeline/$options{pipeline_id}");

## remove the lock file
if ( $options{lock_file} ) {
    close $lockfh;
    unlink $options{lock_file};
}

exit(0);


sub _log {
    my $msg = shift;
    
    print $logfh "$msg\n" if $logfh;
}

sub check_parameters {
    
    ## pipeline_id and repository_root are required
    unless ( defined $options{pipeline_id} && $options{repository_root} ) {
        print STDERR "pipeline_id and repository_root options are required\n\n";
        pod2usage( {-exitval=>1, -verbose => 2, -output => \*STDOUT} );
    }
    
    ## make sure the repository root has a Workflow directory
    unless ( -d "$options{repository_root}/Workflow" ) {
        print STDERR "\n\nthe repository root passed doesn't contain an asmbls directory.\n\n";
        exit(1);
    }
    
    ## make sure the repository root has an output_repository directory
    unless ( -d "$options{repository_root}/output_repository" ) {
        print STDERR "\n\nthe repository root passed doesn't contain an output_repository directory.\n\n";
        exit(1);
    }
}

sub find_remove {
    my $dir = shift;
    
    finddepth(
        { 
            follow => 0,
            no_chdir => 1,
            wanted => \&remove_recursively
        }, $dir
    );
}

sub remove_recursively {
    my $thing = $File::Find::name;
    
    ## is it a file?
    if (-f $thing) {
        unless ( unlink($thing) ) {
            _log("failed to unlink $thing");
        }
    ## is it a directory?
    } elsif (-d $thing) {
        unless ( rmdir($thing) ) {
            _log("failed to rmdir $thing");
        }
    } else {
        _log("ERROR: failed to delete $thing because I don't know what it is.");
    }
    
}




