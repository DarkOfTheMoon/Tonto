#!/usr/bin/perl
#*******************************************************************************
# This script runs all the tests in a test directory.
#
# All command line arguments are compulsory - run the script without them to get
# the usage message.
#
# It expects that the input for the program is the file "stdin", and the output
# file is "stdout".  Files in the test directory should be matched pairs, with
# the first part of their name being "stdin" or "stdout", and the rest being
# identical.  Files that are not matched pairs like this are skipped.
#
# (c) Daniel Grimwood, University of Western Australia, 2004.
#
# $Id$
# 
#*******************************************************************************

use strict;
use English;
use ExtUtils::Command;
use File::Basename ('basename');
use File::Spec ('splitpath','catpath');
use File::Copy ('copy');

my $testdir = "";
my $program = "";
my $cmp = "";

&analyse_arguments(@ARGV);

# read the list of input files
opendir(TESTDIR,$testdir) || die "cannot open directory $testdir";
my @inputfiles = grep { /^stdin.+/ && -f "$testdir/$_"} readdir(TESTDIR);
foreach my $x (@inputfiles) { $x = $testdir . "/" . $x; }
closedir(TESTDIR);

my $failed = 0;
my $skipped = 0;
my $agreed = 0;
my $disagreed = 0;
my $ntests = $#inputfiles+1;

if ($ntests>0) {
  print "Using the program \"$program\".\n";
  print "Running tests in directory \"$testdir\":\n\n"
}

#main loop over tests
foreach my $input (@inputfiles) {

  # Get the output file name from the input file name.
  my ($volume,$dir,$file) = File::Spec -> splitpath($input);
  $file =~ s/^stdin/stdout/;
  my $output = File::Spec -> catpath($volume,$dir,$file);

  if (-f $output) {
    print "running \"$input\" ... ";

    copy($input,"stdin");

    # run the program.
    if (system($program) != 0) {
      $failed++;
      print "failed\n";
    } else {
      if (system("$cmp $output stdout")==0) {
        $agreed++;
        print "agreed\n";
      } else {
        $disagreed++;
        print "disagreed\n";
      }
    }
  } else {
    print "skipping \"$input\" ... ";
    $skipped++;
    print "no test output file!\n";
  }
}

# print the summary
print "\n\nSummary:\n";
print "There are $ntests tests;\n";
if ($agreed>0) {print "  $agreed gave correct results.\n";}
if ($disagreed>0) {print "  $disagreed gave incorrect results.\n";}
if ($failed>0) {print "  $failed failed to run correctly.\n";}
if ($skipped>0) {print "  $skipped skipped.\n";}


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

   if ($testdir eq "" || ! -d $testdir) {
     warn " Error : \"$testdir\" is not a directory";
     $argerr = 1;
   }

   if ($program eq "") {
     warn " Error : \"$program\" is not an executable program";
     $argerr = 1;
   }

   if ($cmp eq "") {
     warn " Error : \"$cmp\" is not an executable program";
     $argerr = 1;
   }

   if ($argerr) {
     print << 'EOF';

 Usage:
    perl -w perform_tests.pl -testdir dir -program prog -cmp cmp

 Where:

    -testdir dir   means test all files in the directory "dir".  All files
                   beginning with "stdin" are expected to be test jobs.  Those
                   without a corresponding "stdout" file will be skipped.  E.g.
                   the files "stdin.h2o.rhf" and "stdout.h2o.rhf" go together.

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

