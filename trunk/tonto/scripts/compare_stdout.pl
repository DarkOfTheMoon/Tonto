#!/usr/bin/perl
#*******************************************************************************
# This script compares two stdout files.
# It ignores predefined differences, such as date/time, version number, and
# platform identifier.
#
# (c) Daniel Grimwood, University of Western Australia, 2004.
#
# $Id$
# 
#*******************************************************************************
use strict;

my $filenamea = shift;
my $filenameb = shift;

open(FILEa,$filenamea);
open(FILEb,$filenameb);

my $equal = 1;
while(my $lineb = <FILEb>) {
  my $linea = <FILEa>;

  # if EOF on $filea, then the files are not equal.
  if (not defined $linea) {$equal = 0; last;}

  # If they are equal, then move onto the next line.
  if ($linea eq $lineb) {next;}

  # Parts of these lines should not be compared.
  if ($linea =~ m'^\s*Version: ') { $linea = $&}
  if ($lineb =~ m'^\s*Version: ') { $lineb = $&}
  if ($linea =~ m'^\s*Platform: ') { $linea = $&}
  if ($lineb =~ m'^\s*Platform: ') { $lineb = $&}
  if ($linea =~ m'^\s*Build-date: ') { $linea = $&}
  if ($lineb =~ m'^\s*Build-date: ') { $lineb = $&}
  if ($linea =~ m'^\s*Timer started at ') { $linea = $&}
  if ($lineb =~ m'^\s*Timer started at ') { $lineb = $&}
  if ($linea =~ m'^\s*Wall-clock time taken for job "(.*)" is ') { $linea = $&}
  if ($lineb =~ m'^\s*Wall-clock time taken for job "(.*)" is ') { $lineb = $&}
  if ($linea =~ m'^\s*CPU time taken for job "(.*)" is ') { $linea = $&}
  if ($lineb =~ m'^\s*CPU time taken for job "(.*)" is ') { $lineb = $&}

  if ($linea ne $lineb) {
    $equal = 0;
    last;
  }
}

my $linea = <FILEa>;
# if EOF on $filea, then the files are not equal.
if (defined $linea) {$equal = 0;}

#if ($equal) {
#  print "$filenamea and $filenameb are equal\n";
#} else {
#  print "$filenamea and $filenameb are not equal\n";
#}

close(FILEb);
close(FILEa);

exit (! $equal);
