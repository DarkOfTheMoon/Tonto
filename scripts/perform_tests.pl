#!/usr/bin/perl
#*******************************************************************************
# This script runs all the tests in a test directory.
#
# All command line arguments are compulsory - run the script without them to get
# the usage message.
#
# (c) Daniel Grimwood, University of Western Australia, 2004.
#
# $Id$
# 
#*******************************************************************************

use strict;
use English;
use File::Copy ('copy');

my $testdir = "";
my $program = "";
my $cmp = "";

&analyse_arguments(@ARGV);

# read the list of test jobs
opendir(TESTDIR,$testdir) || die "cannot open directory $testdir";
my @testdescriptionfiles = grep { /^test/ && -f "$testdir/$_"} readdir(TESTDIR);
#foreach my $x (@inputfiles) { $x = $testdir . "/" . $x; }
closedir(TESTDIR);

my $failed = 0;
my $agreed = 0;
my $disagreed = 0;
my $ntests = $#testdescriptionfiles+1;

if ($ntests>0) {
  print "Using the program \"$program\".\n";
  print "Running tests in directory \"$testdir\":\n\n"
}

#main loop over tests
foreach my $testdescription (@testdescriptionfiles) {

  # Read the input and output files from the test description file.
  open(TEST,"< $testdir/$testdescription");
  my %inputs = ();
  my %outputs = ();
  while (<TEST>) {
    if (m/input:\s+(.+)\s+(.+)/) { $inputs{$1} = $2; }
    if (m/output:\s+(.+)\s+(.+)/) { $outputs{$1} = $2; }
  }

  # Copy the input files to the test directory.
  foreach my $input (keys(%inputs)) {
    copy("$testdir/$input",$inputs{$input});
  }

  print "running \"$testdescription\" ... ";

  # run the program.
  if (system($program) != 0) {
    $failed++;
    print "failed\n";
  } else {
    my $ok = 1;
    foreach my $output (keys(%outputs)) {
      my $out1 = "$testdir/$output";
      my $out2 = $outputs{$output};
      copy("$out1","$out2");
      $ok = ($ok && ! system("$cmp $out1 $out2"));
    }
    if ($ok) {
      $agreed++;
      print "agreed\n";
    } else {
      $disagreed++;
      print "disagreed\n";
    }
  }

  # Delete the test files.  These are the input and output files read in from
  # the test description file.  Any other files created by the test job should
  # be deleted by the test job.
  unlink values(%inputs);
  unlink values(%outputs);
}

# print the summary
print "\n\nSummary:\n";
print "There are $ntests tests;\n";
if ($agreed>0) {print "  $agreed gave correct results.\n";}
if ($disagreed>0) {print "  $disagreed gave incorrect results.\n";}
if ($failed>0) {print "  $failed failed to run correctly.\n";}


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

