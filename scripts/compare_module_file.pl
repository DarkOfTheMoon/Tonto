# Compare two .mod files which are given on the command line.
#
# Note that if a platform (i.e. a compiler and operting system) is specified on
# the command line that the script does not know about, then it is not an error.
# In such a case the script is like "cmp -s".  This is to allow portability to
# untested systems without freeking out the end-user.
#
#*******************************************************************************
# (c) Daniel Grimwood, University of Western Australia, 2000-2002
#
# $Id$
#
#*******************************************************************************

#*******************************************************************************
# Set up the hash array of platform known, and the subroutine to call for each
# platform. 
#
# In most cases the module file format will probably only depend on the
# compiler, but we allow it to depend on the OS just in case.
#
# When writing the routines, remember that "-" is reserved, so change it to "_".
# Don't forget to write the routine at the bottom of the script.
my (%platform_array);
%platform_array = (
  "ABSOFT-f95-on-LINUX"    =>  ABSOFT_f95_on_LINUX,
  "COMPAQ-f90-on-OSF1"     =>  COMPAQ_f90_on_OSF1,
  "COMPAQ-f95-on-OSF1"     =>  COMPAQ_f95_on_OSF1,
  "COMPAQ-f95-on-LINUX"    =>  COMPAQ_f95_on_LINUX,
  "DEC-f90-on-OSF1"        =>  DEC_f90_on_OSF1,
  "DEC-f95-on-OSF1"        =>  DEC_f95_on_OSF1,
  "FUJITSU-f90-on-LINUX"   =>  FUJITSU_f90_on_LINUX,
  "FUJITSU-f95-on-LINUX"   =>  FUJITSU_f95_on_LINUX,
  "IBM-xlf-on-AIX"         =>  IBM_xlf_on_AIX,
  "IBM-xlf90-on-AIX"       =>  IBM_xlf90_on_AIX,
  "INTEL-ifc-on-LINUX"     =>  INTEL_ifc_on_LINUX,
  "LAHEY-lf95-on-LINUX"    =>  LAHEY_lf95_on_LINUX,
  "MIPSPRO-f90-on-IRIX64"  =>  MIPSPRO_f90_on_IRIX64,
  "WORKSHOP-f90-on-SUNOS"  =>  WORKSHOP_f90_on_SUNOS,
  "WORKSHOP-f95-on-SUNOS"  =>  WORKSHOP_f95_on_SUNOS);

#*******************************************************************************
# Argument checking.
#
$argerr=0;
$n_arg=$#ARGV+1;
$n_arg >= 2 || do {print STDERR "Error : need at least two arguments\n"; $argerr=1; };
@ARGS = @ARGV[0 .. $n_arg-3];
$file1 = $ARGV[$n_arg-2];
$file2 = $ARGV[$n_arg-1];

while (@ARGS) {
  $arg=shift @ARGS;
  for ($arg) {
    /^-platform/ && do {
      $fc=shift @ARGS;
      defined $fc || do {print STDERR "Error : no platform specified\n"; $argerr=1};
      last;
    };
    print STDERR ("Error : unexpected argument $arg\n");
    $argerr=1;
  }
}

if ($argerr==1) {
  warn(
    "\nUsage :\n",
    "\t perl -w compare_module_file.perl [-platform platform_id] \\\n",
    "\t\t filename1 filename2 \n",
    "\n",
    "Where :\n",
    "\tfilename1 and filename2 are the two files to compare.\n",
    "\t\"-platform platform_id\" specifies the name of the platform.\n");
   print STDERR "\nThe following list of platforms are recognised by -platform :\n";
   foreach $word (keys %platform_array) { print STDERR "\t$word\n"; }
   print STDERR "\n";
   exit 1;
}

#*******************************************************************************
# check whether files exist.
#
(-f $file1) or die "File $file1 does not exist\n";
(-f $file2) or die "File $file2 does not exist\n";

#*******************************************************************************
# quick filesize comparison.
#
$size1 = (stat($file1))[7];
$size2 = (stat($file2))[7];
($size1 == $size2) or exit 1;

open(FILE1,$file1) or die "Cannot open $file1\n";
open(FILE2,$file2) or die "Cannot open $file2\n";

#*******************************************************************************
# In this bit, we farm out to various routines to set an array of file offsets
# where differences between the files are to be ignored.  Then do the
# comparison.
@skip_array = ();
if (defined $fc) {
  $routine = $platform_array{$fc};
  defined ($routine) && &$routine; # call the corresponding subroutine to $fc
}
$result = &do_compare();  # do the actual comparison
close(FILE2);
close(FILE1);
exit $result;

#*******************************************************************************
# Now for the subroutines.
#*******************************************************************************
$i = 0;
sub do_compare {
  while ((! eof FILE1) && (! eof FILE2)) {
    $i++;
    if (getc(FILE1) ne getc(FILE2)) {
      # should we ignore this file offset?
      if (scalar(grep (/^$i$/,@skip_array)) eq 0) {
        return 1;
      }
    }
  }
  return 0;
}

#*******************************************************************************
# User defined subroutines for each platform...

sub COMPAQ_f90_on_OSF1 {
  push @skip_array,(25,26,27,45,46,47);
# 45,46,47 in Compaq Fortran X5.4A
}

sub COMPAQ_f95_on_OSF1 {
  push @skip_array,(25,26,27,45,46,47);
# 45,46,47 in Compaq Fortran X5.4A
}

sub COMPAQ_f95_on_LINUX {
  push @skip_array,(48,49,50,51);
}

sub DEC_f90_on_OSF1 {
# don't skip anything.
}

sub DEC_f95_on_OSF1 {
# don't skip anything.
}

sub FUJITSU_f90_on_LINUX {
# don't skip anything.
}

sub FUJITSU_f95_on_LINUX {
# don't skip anything.
}

sub IBM_xlf_on_AIX {
# version 5.1, untested, copied from xlf90 below.
  @reverse = (29,30,31,32,33,34,35,36,37,38,39,40,41,42);
  foreach $i (@reverse) {
    push @skip_array,$size1-$i+1;
  }
}

sub IBM_xlf90_on_AIX {
# version 5.1.  Offsets start from end of file.
  @reverse = (29,30,31,32,33,34,35,36,37,38,39,40,41,42);
  foreach $i (@reverse) {
    push @skip_array,$size1-$i+1;
  }
}

sub INTEL_ifc_on_LINUX {
# version 7.  Offsets start from end of file.
  @reverse = (5,6,7,8,9,10,51,52,53,54,55,56,57,58);
  foreach $i (@reverse) {
    push @skip_array,$size1-$i+1;
  }
}

sub LAHEY_lf95_on_LINUX {
# don't skip anything.
}

sub MIPSPRO_f90_on_IRIX64 {
# don't skip anything.
}

sub WORKSHOP_f90_on_SUNOS {
# don't skip anything.
}

sub WORKSHOP_f95_on_SUNOS {
# don't skip anything.
}


sub ABSOFT_f95_on_LINUX {
# don't skip anything.
}

