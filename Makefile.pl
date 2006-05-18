#!/usr/bin/perl

#  Run this script to configure the Makefile for your system.
#  It runs some tests such as determining what your compiler is.

# This module is added manually, since it is not in the perl distribution.
push @INC,'./scripts';
require File::Which;
import File::Which 'which';           # An implementation of the Unix "which" command.

use POSIX 'uname';                    # Need this for uname.
use Getopt::Long;                     # Get the command line options.
use File::Spec 'splitpath';           # To get the path to files.

my $OS = '';                          # Name of the operating system.
my $MAKE = '';
my $SRCDIR = '.';                     # Default directory for the source files.
my $INSTALLDIR = '/usr/local/bin';    # Default directory to install executables.
my $PERL = '';                        # Location of the perl executable.
my $FC = '';                          # Location of the compiler executable.
my $VENDOR = '';                      # Name of the compiler vendor.
my $havelibs = 0;                     # Whether have determined the libraries to use.
my $FSUFFIX = 'f';                    # Fortran files have this suffix.
my $f95_compiler = 0;                 # Whether is an f95 compiler or just f90.
my $PLATFORM_ID = '';                 # e.g. LAHEY-lf95-on-WINDOWS
my $PLATFORM_ID_ = '';                # e.g. LAHEY_lf95_on_WINDOWS
my $PLATFORM_INFO_FILE = '';          # This is the compiler vendor and operating system
my $INT_KIND = 4;                     # The default integer kind
my $BIN_KIND = 4;                     # The default logical kind

my $show_help = 0;
my $show_defaults = 0;
my ($tmp1,$tmp2);

my %vendors = (                                # This contains a list of string
'LAHEY'      => 'Lahey',                       # identifiers for each vendor.
'FUJITSU'    => '(?<!Lahey\/)Fujitsu',
'COMPAQ'     => 'Compaq',
'DEC'        => 'Digital',
'IBM'        => 'IBM',
'IBM'        => 'XL Fortran',
'NAG'        => 'NAG',
'HP'         => 'HP',
'WORKSHOP'   => 'WorkShop',
'MIPSPRO'    => 'MIPSpro',
'PGI'        => 'Portland',
'INTEL'      => 'Intel',
'ABSOFT'     => 'Absoft',
'GNU'        => '(g95|gfortran)',
);

################################################################################
# Process the command line arguments, if any.

GetOptions(  'help' => \$show_help,
             'show_defaults' => \$show_defaults,
             'installdir=s' => \$INSTALLDIR,
             'fc=s' => \$FC,
             'srcdir=s' => \$SRCDIR,
) || do { &show_options; exit 1; };

if ($show_help) {
  print STDOUT "\n";
  print STDOUT "This script sets up the Makefile for Tonto to compile on your system.\n";
  print STDOUT "You probably do not need to set any options.\n";
  &show_options;
}

if ($show_defaults) {
  print STDOUT "\n";
  print STDOUT "Default directory for source files is \"$SRCDIR\"\n";
  print STDOUT "Default directory to install programs to is \"$INSTALLDIR\"\n";
  exit 0;
}

if ($show_help || $show_defaults) { exit 0; }

-d "$SRCDIR" || do { print STDERR "Error : Source directory does not exist\n";
                   exit 0;
                 };

-f "$SRCDIR/Makefile.in" || do { print STDERR "Error : Makefile.in does not exist in $SRCDIR\n";
                                 exit 0;
                               };

################################################################################

print STDERR "Getting operating system name ...";
$OS = &get_OS;
&print_result($OS);

print STDERR "Checking for perl ...";
$PERL = &check_for_program('perl');
&print_result($PERL);

print STDERR "Checking for make ...";
($tmp,$MAKE) = &check_for_programs('gmake','make');
&print_result($MAKE);

if ($MAKE ne '') {
  print STDERR 'Checking whether GNU make ...';
  $have_gnu_make = &check_is_GNU_make;
  &print_boolean($have_gnu_make);
}

print STDERR "Checking for Fortran compiler ...";
if (defined $FC && $FC ne '') {
  if (-f $FC) {
    $FULLFC = $FC;
    ($tmp1,$tmp2,$FC) = File::Spec->splitpath($FULLFC);
  } else {
    ($FC,$FULLFC) = &check_for_programs($FC);
  }
} else {
  ($FC,$FULLFC) = &check_for_programs('mpif90','lf95','frtvpp','ifort','ifc',
             'frt','xlf90','pgf90','f95','f90','g95','g90','gfortran');
}
&print_result($FULLFC);

print STDERR "\n";  # Just a gap to separate checks from Makefile stuff.

if ($FC ne '') {

  print STDERR "Determining Fortran compiler vendor ...";
  $VENDOR = &get_vendor($FC);
  if ($VENDOR ne '') {&print_result($VENDOR)}
  else {&print_result('cannot determine');}

  $PLATFORM_ID = "${VENDOR}-${FC}-on-${OS}";
  $PLATFORM_ID_ = "${VENDOR}_${FC}_on_${OS}";
  $PLATFORM_INFO_FILE = "${SRCDIR}/platforms/${PLATFORM_ID}";

  print STDERR "Determining Fortran default integer kind ...";
  &get_default_integer_kind;
  &print_result($INT_KIND);

  print STDERR "Determining Fortran default logical kind ...";
  &get_default_logical_kind;
  &print_result($BIN_KIND);

  print STDERR "Determining Fortran default double precision kind ...";
  &get_default_double_precision_kind;
  &print_result($REAL_KIND);

  print STDERR "Options for your compiler are in $PLATFORM_INFO_FILE\n";
  &check_siteconfig;

} else {

  die "Cannot find a Fortran compiler on your system.";

}

&do_substitutions_into_Makefile;

################################################################################
sub print_result {
  if (defined $_[0] && $_[0] ne '') {
    print STDERR " $_[0]\n";
  } else {
    print STDERR " none\n";
  }
}

################################################################################
sub print_boolean {
  if ($_[0]) {
    print STDERR " yes\n";
  } else {
    print STDERR " no\n";
  }
}

################################################################################
sub get_OS {
  my($tmp);
  $tmp = (POSIX::uname())[0];
  if (! defined $tmp || $tmp eq '') {$tmp = 'unknown'}
  $tmp =~ s/cygwin(.*)/windows/i;
  $tmp =~ s/(?<=windows)(.*)//i;
  return uc($tmp);
}

################################################################################
sub check_for_programs {
  my($tmp,$word);
  for $word (@_) {
    $tmp = &check_for_program($word);
    if (defined $tmp && $tmp ne '') {return ($word,$tmp);}
  }
  return ('','');
}

################################################################################
sub check_for_program {
  return which("$_[0]");
}

################################################################################
sub check_if_f95_compiler {
  my($CONFTEST);
  open(CONFTEST,"conftest.${FSUFFIX}",">");
  print CONFTEST "program main\n";
  print CONFTEST "  integer :: i\n";
  print CONFTEST "  real, dimension(10) :: a\n";
  print CONFTEST "  forall(i=1:10)\n";
  print CONFTEST "    a(i)=1.0\n";
  print CONFTEST "  end forall\n";
  print CONFTEST "end program\n";
  close(CONFTEST);
  unlink("conftest.exe","conftest.o","conftest.obj");
  system("${FC} -O0 -g0 -o conftest.exe conftest.${FSUFFIX} 2>&1");
  if (-x 'conftest.exe') {
    $f95_compiler = 1;
  } else {
    $f95_compiler = 0;
  }
  unlink("conftest.${FSUFFIX}","conftest.exe","conftest.o","conftest.obj");
}

################################################################################
sub get_default_integer_kind {
  $INT_KIND = "4";
  my($INTTEST);
  open(INTTEST,">","inttest.f90");
  print INTTEST "program main\n";
  print INTTEST "  integer :: i\n";
  print INTTEST "  print *,kind(i)\n";
  print INTTEST "end program\n";
  close(INTTEST);
  unlink("inttest.exe","inttest.o","inttest.obj");
  system("${FC} -o inttest.exe inttest.f90 2>&1");
  if (! -x 'inttest.exe') { return }
  system("./inttest.exe > inttest.out");
  if (open(INTTEST,"<","inttest.out")) {
     $INT_KIND = <INTTEST>;
     chomp($INT_KIND);
     $INT_KIND =~s/ *//g;
  } 
  unlink("inttest.f90","inttest.out","inttest.exe","inttest.o","inttest.obj");
}

################################################################################
sub get_default_double_precision_kind {
  $REAL_KIND = "8";
  my($REALTEST);
  open(REALTEST,">","realtest.f90");
  print REALTEST "program main\n";
  print REALTEST "  print *,kind(1.0d0)\n";
  print REALTEST "end program\n";
  close(REALTEST);
  unlink("realtest.exe","realtest.o","realtest.obj");
  system("${FC} -o realtest.exe realtest.f90 2>&1");
  if (! -x 'realtest.exe') { return }
  system("./realtest.exe > realtest.out");
  if (open(REALTEST,"<","realtest.out")) {
     $REAL_KIND = <REALTEST>;
     chomp($REAL_KIND);
     $REAL_KIND =~s/ *//g;
  } 
  unlink("realtest.f90","realtest.out","realtest.exe","realtest.o","realtest.obj");
}

################################################################################
sub get_default_logical_kind {
  $BIN_KIND = "4";
  my($BINTEST);
  open(BINTEST,">","bintest.f90");
  print BINTEST "program main\n";
  print BINTEST "  logical :: l\n";
  print BINTEST "  print *,kind(l)\n";
  print BINTEST "end program\n";
  close(BINTEST);
  unlink("bintest.exe","bintest.o","bintest.obj");
  system("${FC} -o bintest.exe bintest.f90 2>&1");
  if (! -x 'bintest.exe') { return }
  system("./bintest.exe > bintest.out");
  if (open(BINTEST,"<","bintest.out")) {
     $BIN_KIND = <BINTEST>;
     chomp($BIN_KIND);
     $BIN_KIND =~s/ *//g;
  } 
  unlink("bintest.f90","bintest.out","bintest.exe","bintest.o","bintest.obj");
}

################################################################################
sub check_is_GNU_make {
  my($is_gnu,$MAKE_OUT);
  $is_gnu = 0;
  defined($MAKE) or die "no MAKE variable defined";
  system("${MAKE} -v > conf.test 2>&1");
  if (! -f "conf.test") {return(0)};
  open(MAKE_OUT,"conf.test");
  while (<MAKE_OUT>) {
    if (m/\bGNU\b/o) {$is_gnu = 1}
  }
  close(MAKE_OUT);
  unlink("conf.test");
  return($is_gnu);
}

################################################################################
sub get_vendor {
  my(@trystring,$vec,$vendor,$search);
  open(CONFTEST,"> conftest.${FSUFFIX}");
  print CONFTEST "program main\n";
  print CONFTEST "  write(*,*) 1\n";
  print CONFTEST "end program\n";
  close(CONFTEST);

  unlink("conf.test");
  $vendor = 'UNKNOWN';
  @trystr = (
    "$FC -V >> conf.test 2>&1",
    "$FC -v >> conf.test 2>&1",
    "$FC -version >> conf.test 2>&1",
    "$FC --version >> conf.test 2>&1",
    "$FC -V conftest.${FSUFFIX} >> conf.test 2>&1",
    "$FC -v conftest.${FSUFFIX} >> conf.test 2>&1",
    "$FC -version conftest.${FSUFFIX} >> conf.test 2>&1",
    "$FC --version conftest.${FSUFFIX} >> conf.test 2>&1",
  );
  THIS : foreach $str (@trystr) {
    system($str);
    foreach $ven (keys(%vendors)) {
      open(CONFOUT,"< conf.test") || next;
      $search = $vendors{$ven};
      $tmp = $search;
      while (<CONFOUT>) {
        if (m/$search/) {
          $vendor = $ven;
          close(CONFOUT);
          last THIS;
        }
      }
      close(CONFOUT);
    }
    if ($vendor ne 'UNKNOWN') {last}
  }
  unlink("conf.test","conftest.${FSUFFIX}","a.out","conf.exe");
  return $vendor;
}

################################################################################
sub check_siteconfig {
  if (! -f $PLATFORM_INFO_FILE) {
    print STDERR "\n";
    print STDERR "File ${PLATFORM_INFO_FILE} created from template.\n";
    print STDERR "Please edit ${PLATFORM_INFO_FILE}.\n";
    open(SCt,"${SRCDIR}/platforms/template");
    open(SC,"> $PLATFORM_INFO_FILE");
    while(<SCt>) {
      s/^(FC.*?=)(.*)/$1 $FC/;
      print SC;
    }
    close(SC);
    close(SCt);
  }
}

################################################################################
sub show_options {
  print STDOUT "\n";
  print STDOUT "Valid options include :\n";
  print STDOUT "  --help                 Show this message and then exit.\n";
  print STDOUT "  --srcdir=DIR           The source files are in DIR.\n";
  print STDOUT "  --installdir=DIR       Compiled programs go into DIR.\n";
  print STDOUT "  --fc=COMPILER          Set the fortran compiler command to COMPILER.\n";
  print STDOUT "  --show_defaults        Show default settings.\n";
}

################################################################################
sub do_substitutions_into_Makefile {
  -f "$SRCDIR/Makefile.in" || do {print STDERR "Makefile.in not found in $SRCDIR"; exit 1};
  open(INFILE,"< Makefile.in");
  open(OUTFILE,"> Makefile");
  while(<INFILE>) {
    s/\@INSTALLDIR\@/$INSTALLDIR/g;
    s/\@SRCDIR\@/$SRCDIR/g;
    s/\@PERL\@/$PERL/g;
    s/\@MAKE\@/$MAKE/g;
    s/\@OS\@/$OS/g;
    s/\@FC\@/$FULLFC/g;
    s/\@PLATFORM_INFO_FILE\@/$PLATFORM_INFO_FILE/g;
    s/\@PLATFORM_ID\@/$PLATFORM_ID/g;
    s/\@PLATFORM_ID_\@/$PLATFORM_ID_/g;
    s/\@INT_KIND\@/$INT_KIND/g;
    s/\@BIN_KIND\@/$BIN_KIND/g;
    s/\@REAL_KIND\@/$REAL_KIND/g;
    print OUTFILE;
  }
  close(OUTFILE);
  close(INFILE);
}
