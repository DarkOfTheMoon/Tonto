#!/usr/bin/perl

# This is a perl script used to run the quality assurance (QA) tests in the
# "tests" directory. The output from each test job is compared with the
# reference data set.

use File::Copy;
use File::Path;
use File::Compare;

#-------------------------------------------------------------------------------
# Set defaults  
#-------------------------------------------------------------------------------

# default program executable to be tested
$exec = "/home/dylan/tonto/INTEL-ifc-on-LINUX/run_molecule.exe";

# default test directory
$test_dir = "./tests";

# default skip regexp
push @skip, '^\s*$';
push @skip, '^\s*Timer started';
push @skip, '^\s*Version:';
push @skip, '^\s*Platform:';
push @skip, '^\s*Build-date:';
push @skip, '^\s*Wall-clock time taken';
push @skip, '^\s*CPU time taken';
push @skip, '^\s*Warning in routine';
push @skip, '^\s*Routine call stack:';
push @skip, '^\s*Call *Routine name *Memory used';
push @skip, '^    \d+\.   [A-Z.]+:\w+\s+\d+\s*$';
push @skip, 'Memory usage report';
push @skip, '^\s*Memory used                =';
push @skip, '^\s*Maximum memory used        =';
push @skip, '^\s*Memory blocks used         =';
push @skip, '^\s*Maximum memory blocks used =';
push @skip, '^\s*Call stack level           =';
push @skip, '^\s*Maximum call stack depth   =';



#-------------------------------------------------------------------------------
# Argument parsing.
#-------------------------------------------------------------------------------

$argerr=0;

while (@ARGV) {
    $arg=shift;
    SWITCH: for ($arg) {
        /^-exec$/      && do { $exec = shift; last; };
        /^-test_dir$/  && do { $test_dir = shift; last; };
        /^-skip$/      && do { push (@skip, shift); last; };
        warn "Error : unexpected argument $arg\n";
        $argerr=1;
    }
}

#-------------------------------------------------------------------------------
# Error checks.
#-------------------------------------------------------------------------------

$exec ne ''     || do {$argerr=1; warn "Error: -exec option is null string\n"};
$test_dir ne '' || do {$argerr=1; warn "Error: -test_dir option is null string\n"};
#-d $exec        || do {$argerr=1; warn "Error: $exec option is not an executable program\n"};
-d $test_dir    || do {$argerr=1; warn "Error: $test_dir option is not a directory\n"};

#-------------------------------------------------------------------------------
# Print out standard help message if there's an error.
#-------------------------------------------------------------------------------

if ($argerr==1) {
    die(
        "Usage:\n",
        "\n",
        "   perl -w run_QA_tests.pl [-tests_dir dir_name] [-skip regexp]\n",
        "\n",
        "Where:\n",
        "\n",
        "  -test_dir dir_name\n",
        "\n",
        "      Specify directory \"dir_name\" where tests inputs and outputs are located.\n",
        "      Inputs must have file extension .in., Outputs must have file extension .out\n",
        "\n",
        "  -skip regexp\n",
        "\n",
        "      When comparing outputs, ignore any lines which match \"regexp\".\n");
}

#-------------------------------------------------------------------------------
# Loop over test jobs
#-------------------------------------------------------------------------------


opendir(DIR, $test_dir) || die "can’t opendir $test_dir: $!";

chdir $test_dir;

while (defined( $infile = readdir(DIR))) {

   next if (  -d $infile);            # Make sure $infile is a real file
   next if (! -f $infile);        
   next if ($infile =~ /\.out$/);
   next if ($infile !~ /(\w+)\.in$/);

   $head = $1;                        # Get the $outfile, check it is there
   $outfile = "$head.out";
   if (! -f $outfile) { die("Output file $outfile does not exist"); }

   print "Executing $head ... ";

   if (! -d "job") { mkpath("job"); } # Make the job directory, and run there
   copy($infile,"job/stdin");
   chdir "job";
   system($exec);
   if (same("stdout","../$outfile")) { print "PASSED.\n"; }
   else                              { print "FAILED.\n"; }
   chdir "..";

   rmtree("job");                     # Cleanup and do the next job
}

closedir DIR;

#-------------------------------------------------------------------------------
# Check for equality. Return 1 if they are the same.
#-------------------------------------------------------------------------------
sub same {

   $file1 = shift;                        # File names to compare
   $file2 = shift;

   if (! -f $file1) { die("Output file $file1 does not exist") }
   if (! -f $file2) { die("Output file $file2 does not exist") }

   open(FILE1, $file1);
   open(FILE2, $file2);

   PAIR_LINE_LOOP:
   while (1) {                             # Loop over paurs of lines ...

      $line1 = <FILE1>;
      $line2 = <FILE2>; 
      return (1) if (!$line1 and !$line2); # Same if both end at the same time
      return (0) if ( $line1 and !$line2);
      return (0) if (!$line1 and  $line2);

      chomp($line1);
      chomp($line2);

      OK_LINE1: 
      while (1) {
         foreach $skip (@skip) {
            next if $line1 !~ /${skip}/;   # Skip explicitly ignored -skip lines
            $line1 = <FILE1>;
            last OK_LINE1 if (!$line1);
            chomp($line1); next OK_LINE1;
         }
         last OK_LINE1;
      }

      OK_LINE2: 
      while (1) {
         foreach $skip (@skip) {
            next if $line2 !~ /${skip}/;   # Skip explicitly ignored -skip lines
            $line2 = <FILE2>; 
            last OK_LINE2 if (!$line2);
            chomp($line2); next OK_LINE2;
         }
         last OK_LINE2;
      }

      return (0) if ( $line1 ne   $line2); # Lines differ, Not same
      return (0) if ( $line1 and !$line2);
      return (0) if (!$line1 and  $line2);
      return (1) if (!$line1 and !$line2);
   }

}
