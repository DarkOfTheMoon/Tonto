#!/usr/bin/perl
#*******************************************************************************
#
# This script runs all the tests in a test directory. The tests are contained
# in their own directory, and any bad tests are copied back there for later
# comparison. -- dylan
#
# All command line arguments are compulsory - run the script without them to get
# the usage message.
#
# (c) Daniel Grimwood, University of Western Australia, 2004.
# (c) Dylan Jayatilaka, 2006
#
# $Id$
# 
#*******************************************************************************

use strict;
use English;
use File::Copy ('copy');

# my $testdir = "../tests";
# my $program = "../INTEL-ifc-on-LINUX/run_molecule.exe";
# my $cmp     = "perl -w ./compare_output.pl";
my $testdir = "";
my $program = "";
my $cmp     = "";

&analyse_arguments(@ARGV);

# Open the test suite directory

opendir(TESTDIR,$testdir) || die "cannot open directory $testdir";

# Get the job directories (i.e. those with IO descriptor files)

my $dir = "";
my $job = "";
my @jobs = ();

foreach $job (readdir(TESTDIR)) {
   $dir = "$testdir/$job";
   next if ($job eq "..");
   if (-d $dir) {
      if (-f "$dir/stdin" && -f "$dir/stdout") { push(@jobs,$job) };
   }
}
closedir(TESTDIR);

# foreach $job (@jobs) {
#    print "$job\n";
# }

# exit;

# Counters for the test suite

my $failed = 0;
my $agreed = 0;
my $disagreed = 0;
my $njobs = $#jobs+1;

if ($njobs>0) {
  print "\n";
  print "Using the program \"$program\".\n";
  print "Running tests in directory \"$testdir\":\n\n"
}

# Main loop over tests

foreach my $job (@jobs) {

# print "running \"$job\" ... ";

  # Set stdin and stdout 

  my $input = "";
  my @input = ( "stdin" );
  my $output = "";
  my @output = ( "stdout" );

  # Read extra input and output files from IO file.

  if (open(TEST,"< $testdir/$job/IO")) {
     while (<TEST>) {
       if (m/input\s*:\s+(.+)/)  { push (@input,$1); }
       if (m/output\s*:\s+(.+)/) { push (@output,$1); }
     }
  }

  # Copy the input files to the current directory.

  foreach $input (@input) {
    copy("$testdir/$job/$input",$input);
  }

  # Run the program.

  my $status = "";
  if (system($program) != 0) {
    $failed++;
    $status = "program failed";
  } else {
    my $ok = 1;
    foreach my $output (@output) {
      $ok = ($ok && ! system("$cmp $testdir/$job/$output $output"));
    }
    if ($ok) {
      $agreed++; $status = "passed";
    } else {
      $disagreed++; $status = "FAILED";
      foreach my $output (@output) {
        copy($output,"$testdir/$job/$output".".bad");
      }
    }

  }

format STDOUT_TOP =
Test name                               Status
----------------------------------------------------------
.
format STDOUT =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<
$job,                                   $status
.
write;

  # Delete the test files.  These are the input and output files read in from
  # the test description file.  Any other files created by the test job should
  # be deleted by the test job.

  foreach $input (@input) { unlink $input; }
  foreach $output (@output) { unlink $output; }

}

# Print the summary

print "\nSummary:\n";
print "There are $njobs tests;\n";
if ($agreed>0)    {print "  $agreed gave correct results.\n";}
if ($disagreed>0) {print "  $disagreed gave incorrect results.\n";}
if ($failed>0)    {print "  $failed failed to run correctly.\n";}


sub analyse_arguments {
# Analyse the command line arguments
   my ($arg,$argerr);
   $argerr=0;
   my @args = @_;
   $argerr=1 if (@args==0);

   # Extract the command line arguments
   
   while (@_) {
     $arg = shift;
     $_ = $arg;
     if (/^-/) {
       /^-testdir\b/          && do { $testdir      = shift; next; };
       /^-program\b/          && do { $program      = shift; next; };
       /^-cmp\b/              && do { $cmp          = shift; next; };
       warn "\n Error : unexpected argument $arg\n";
       $argerr=1;
     }
   }

   if ($testdir eq "") {
     warn " Error : -testdir option is empty string";
     $argerr = 1;
   } elsif (! -d $testdir) {
     warn " Error : \"$testdir\" is not a directory";
     $argerr = 1;
   }

   if ($program eq "") {
     warn " Error : -program option is empty string";
     $argerr = 1;
   }

   if ($cmp eq "") {
     warn " Error : -cmp option is empty string";
     $argerr = 1;
   }

   if ($argerr) {
     print << 'EOF';

 Usage:
    perl -w perform_tests.pl -testdir dir -program prog -cmp cmp

 Where:

    -testdir dir   means test all files in the directory "dir".  All files
                   beginning with "test" describe test jobs.  
                   E.g.
                   the files "h2o.rhf.stdin" and "h2o.rhf.stdout" go together.

    -program prog  "prog" is the program to test.  E.g.
                   INTEL-ifort-on-LINUX/run_molecule.exe
                   It should read in the real file "stdin", and output to
                   the real file "stdout".

    -cmp cmp       "cmp" is the comparison program for stdout files.  E.g.
                   "perl -w scripts/compare_stdout.pl"

EOF
   exit (1);
   }
}

