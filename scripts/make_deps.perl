#--------------------------------------------------------------------------------
#
#  >>> Make the module dependecy list for a TONTO module or program
#
#  The following perl script generates an efficient makefile dependecy list 
#  which makes re-use of old .mod files.
#
#  Explanation
#
#  Every .o file depends (implicitly) on the .f90 file from which it is compiled
#  and also on all the .mod module files which it USE's.
#
#  Every .mod file depends on the corresponding .f90 file, and it is generated 
#  at the same time as the corresponding .o file. 
#
#  Sometimes, a .mod file may not change, even though the corresponding .f90
#  and .o files do. For automatic compilation using the "make" program, it is
#  advantageous to keep using the old unchanged .mod file, since then the
#  "make" program will know that any .o files which USE the .mod file need not
#  be updated, and these .o files need not be recompiled, saving considerable
#  time.
#
#  While using the  old .mod file solves the problem of unneccesary
#  recompilation of any .o file which USE's it, another problem arises. That
#  is, the old .mod file will always be out of date with respect to the parent
#  .f90 file from which it comes, and hence "make" will always try to recompile
#  the parent .f90 file, even if the parent .f90 file has not changed.
#
#  To solve this problem, it is clear that any old .mod file cannot depend via
#  any "make" rule on the parent .f90 file, else it will always be out of date,
#  and recompiled. On the other hand, the .mod file does depend on the .f90
#  file, as has been stated above. Clearly, the date checking mechanism must be
#  bypassed when updating the .mod files.
#
#  This can be done if two makes are used to to create an executable.
#  First, the .mod files are made, then the executable is made from these .mod
#  files. By splitting the make into two steps this way, the fact that the .mod
#  files are out of date with respect to the parent .f90 file after the first
#  make does not matter. The second make will not check to see.  This procedure
#  can be implemented in a single make by calling make recursively. The
#  procedure assumes that a correct set of .mod files can be produced in a
#  single step by the first make.
#
#  More specifically, in the first make, any changed .f90 files on which the
#  executable depends are recompiled. New .o files are generated, but the .mod
#  files may or may not be recreated, depending on whether they have changed,
#  or not. The second make, for the same .o files, ensures that any .o files
#  which use the (prehaps new) .mod files created in the first make are
#  recompiled.  This second make should not produce any new and different .mod
#  files; they would have been produced in the first make, assuming that new
#  .mod files are generated only from new code in the parent .f90 file, and not
#  from any new code in any modules which it USE's. (This seems reasonable,
#  otherwise the idea that each module can be separately compiled and used from
#  the given .f90 code is violated). The only errors expected in the second
#  make, will concern incorrectly called routines from USE'd modules.
#
#  Implementation
#
#  Each executable X depends on the .o files of modules which is uses, and also
#  on all the .o files used by these modules. (It is assumed that there no
#  external procedures called). A variable $(X) is defined which contains the
#  list of dependent .o files. Of course, X also depends on the parent file
#  X.f90.
#
#  On the other hand, each .o file depends only on the .mod files which 
#  it USE's, and the corresponding .f90 file.
# 
#  The rule which defines the how the .o and .mod files are made is:
#
#  %.o : %.$(F90SUFFIX) macros update_module_file
#	$(F90) -c -o objects/$(*F).o f90/$(*F).$(F90SUFFIX)
#	update_module_file $(*F).mod
#
#  %.mod : 
#	$(MAKE) $(*F).o
#
#  Note that the .o rule uses the update_module_file to update the .mod file,
#  if it is different. Note also the the .mod file does not depend on any other
#  files, although it can be created, if it is not there, by makeing the
#  corresponding .o file.
#
#  The rule for generating the executable is:
#
#  %.x : %.$(F90SUFFIX) macros
#	$(MAKE) $($(*F))
#	$(F90) -o $@ objects/*.o f90/$(<F) $(LIBS)
#
#  If any of the .o dependents are out of date, those are remade first.  Then,
#  make is called again on the same dependents. Finally, the actual .f90 file
#  is compiled with all the required object files.
#
#  (c) dylan jayatilaka, university of western australia, 1998
#
#  $Id$
#
#-------------------------------------------------------------------------------

@ARGV==2  or die "Expecting 2 arguments, foo file, dependency file.";
$foofile   = $ARGV[1];
$depfile   = $ARGV[2];

open(FOOFILE, $foofile) or die "$FOOFILE does not exist.";
system("rm -f $depfile");
open(DEPFILE,">" . $depfile);

$[ = 1;
$n = 0;
$is_module  = 0;
$is_program = 0;

LINE: while (<FOOFILE>) {
  chop;
  $inp = $_;  # Get the line
  @arg = split(" +",$_);
  if ($inp =~ "^ *module +")  { $unitname = lc($arg[2]); $is_module = 1; }
  elsif ($inp =~ "^ *program +") { $unitname = lc($arg[2]); $is_program= 1; }
  elsif ($inp =~ "^ *[Uu][Ss][Ee] +") {
     $n++;
     $name = lc($arg[3]);
     $used_module_name[$n] = $name;
  }
}

$uselist = "$unitname := \$\(sort";
$modlist = "";
$cont = 1;
$mont = 1;
for ($i=1; $i<=$n; $i++) { 
     if (length($uselist)>60*$cont) {
        $uselist = $uselist . " \\\n   ";
        $cont++;
     }
     $uselist = "$uselist \$" . "($used_module_name[$i])";
     if (length($modlist)> (60*$mont) ) {
        $modlist = $modlist . " \\\n   ";
        $mont = $mont+1;
     }
     $modlist = "$modlist $used_module_name[$i].mod";
}
if ($is_module==1)  {
     print DEPFILE "$uselist $unitname.o)\n";
     print DEPFILE "$unitname.o : $modlist $unitname.f90\n\n";
  }
if ($is_program==1) { 
     print DEPFILE "$uselist)\n";
     print DEPFILE "$unitname.x : \$" ."($unitname)" . " $unitname.f90\n\n";
}
