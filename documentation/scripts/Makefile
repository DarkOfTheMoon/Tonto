# Generated automatically from Makefile.in by configure.
#==============================================================================
#
# >>> Makefile for the TONTO system
#
# You will need GNU make for this to work.
#
# For basic use you should not need to change anything if you ran the
# "configure" script successfully.  Just type "make run_mol.x".
#
# You can add/permute/remove the compiler options $(FFAST), $(FDEBUG) and
# $(FPROF) in the F90 definition to get different versions of the program.  
#
# (c) dylan jayatilaka, daniel grimwood 
#     university of western australia, 1999-2000
#
# $Id$
#
#==============================================================================




F90 = $(FFAST)




prefix := /usr/local
exec_prefix := ${prefix}
installdir := ${exec_prefix}/bin




#==============================================================================
# For normal use you shouldn't have to change anything below here.
#==============================================================================

FC := f95

FFLAGS    := -Cpp -I. -Am -I./modules -M./new_modules -I./interfaces \
             -I./objects -I./f90 -f w -static-flib
FDEBUG    := -g -H aesu
FFAST     := -O -Komitfp -Kloop -Kauto -Kpreex -Keval -x-
F90SUFFIX := f90

#------------------------------------------------------------------------------
# >>> Standard Makefile options
#
# Note: For modules, the f95 compiler produces (temporarily) a .mod file
# in a directory "new_modules". The actual .mod file used by make resides 
# in the "modules" directory (see "VPATH" variable). The temporary .mod file 
# overwrites the old one only if it is different from it. This can save
# a lot of time in compilation.  (see the "update_module_file" script).
#------------------------------------------------------------------------------

COFLAGS  := -M -q
SHELL    := /bin/csh -f
VPATH    := .:./objects:./modules:./f90: \
            ./dependencies:./foofiles:./scripts: \
            ./documentation/htmlfiles:./documentation

.DEFAULT :
.SUFFIXES :
.SUFFIXES : .o .x .$(F90SUFFIX) .dep .foo .html
.PHONY : clean all objectfiles directories install
docdir := ./documentation

#------------------------------------------------------------------------------
# >>> Object files in hierachical order
#
# If you write a new TONTO module, you will need to add its .o filename 
# in the correct hierarchical position below. The correct position is after 
# all the modules which it USE's, but before all the modules which USE it.
#------------------------------------------------------------------------------

basic := types.o system.o time.o str.o int.o dbl.o buffer.o 
array :=  strvec.o   \
          binvec.o   \
            ivec.o   imat.o   imat3.o   imat4.o           \
             vec.o    mat.o    mat3.o    mat4.o    mat5.o \
            cvec.o   cmat.o   cmat3.o   cmat4.o   cmat5.o \
         ivecvec.o                                        \
          vecvec.o matvec.o mat3vec.o mat4vec.o           \
           opvec.o  opmat.o
files := unitnumber.o file.o textfile.o archive.o
diis  := vecdiis.o
basis := rys.o gaussian.o gaussian2.o gaussian4.o \
         shell.o shell1.o shell2.o shell4.o shellvec.o \
         basis.o basisvec.o  
atoms := atom.o atomvec.o 
group := irrep.o irrepvec.o pointgroup.o spacegroup.o crystal.o
mol   := plotgrid.o dftgrid.o scfdata.o \
         mol.o mol_dylan.o mol_chris.o mol_daniel.o mol_main.o

objectfiles := $(basic) $(array) $(files) $(diis) $(basis) $(atoms) $(group) $(mol)

runfiles := $(patsubst foofiles/%, %  , $(wildcard foofiles/run_*.foo))
runfiles := $(sort $(runfiles:.foo=.x))

dependfiles := $(objectfiles:.o=.dep) $(runfiles:.x=.dep)

htmlfiles := $(objectfiles:.o=.html)

f90files := $(objectfiles:.o=.$(F90SUFFIX))

#------------------------------------------------------------------------------
# >>> Targets and dependencies
#------------------------------------------------------------------------------

all : objectfiles run_mol.x

objectfiles : $(objectfiles)

help :
	@echo ""
	@echo "Please supply an argument to make."
	@echo "Common arguments are:"
	@echo ""
	@echo "    help            - displays this screen"
	@echo "    documentation   - makes the html documentation"
	@echo "    run_mol.x       - builds the program run_mol.x"
	@echo "    install         - builds and installs run_mol.x"
	@echo "    clean           - removes built program files"
	@echo "    docsclean       - removes built documentation files"
	@echo "    distclean       - removes all built files"
	@echo ""

install : run_mol.x
	install $(installdir)/run_mol.x ./run_mol.x

clean :
	@if (-d ./dependencies)  echo "rm -f ./dependencies/*"
	@if (-d ./dependencies)  rm -f ./dependencies/*; exit 0
	@if (-d ./objects)       echo "rm -f ./objects/*"
	@if (-d ./objects)       rm -f ./objects/*; exit 0
	@if (-d ./modules)       echo "rm -f ./modules/*"
	@if (-d ./modules)       rm -f ./modules/*; exit 0
	@if (-d ./new_modules)   echo "rm -f ./new_modules/*"
	@if (-d ./new_modules)   rm -f ./new_modules/*; exit 0
	@if (-d ./interfaces)    echo "rm -f ./interfaces/*"
	@if (-d ./interfaces)    rm -f ./interfaces/*; exit 0
	@if (-d ./f90)           echo "rm -f ./f90/*"
	@if (-d ./f90)           rm -f ./f90/*; exit 0
	@rm -f ./run_*.x;      exit 0
	@if (-e ./dependfile)    rm -f ./dependfile

docsclean :
	@if (-d $(docdir)/htmlfiles) echo "rm -f $(docdir)/htmlfiles/*"
	@if (-d $(docdir)/htmlfiles) rm -f $(docdir)/htmlfiles/*; exit 0
	@if (-d $(docdir)/f90files)  echo "rm -f $(docdir)/f90files/*"
	@if (-d $(docdir)/f90files)  rm -f $(docdir)/f90files/*; exit 0
	@if (-d $(docdir)/foofiles)  echo "rm -f $(docdir)/foofiles/*"
	@if (-d $(docdir)/foofiles)  rm -f $(docdir)/foofiles/*; exit 0

distclean : clean docsclean
	@if (-e ./Makefile)   rm -f ./Makefile

distribution :
	./scripts/make_dist

Makefile : Makefile.in configure
	@./configure

configure : configure.in
	@autoconf

#---------------------------------------------------------------------------
# >>> HTML documentation files
#
# This makes HTML documentation for all modules, and stores it in the
# documentation directory.  Point your browser to the "index.html" file for the
# start of the documentation.
#---------------------------------------------------------------------------

documentation : macros Makefile Makefile.in configure configure.in \
           make_navbar make_deps.perl update_module_file update_file \
           foo.perl foo2html.perl TONTO-nav-bar.html
	@if (! -d $(docdir)/scripts)  mkdir $(docdir)/scripts
	@scripts/update_file ./configure $(docdir)/scripts/configure
	@scripts/update_file ./configure.in $(docdir)/scripts/configure.in
	@scripts/update_file ./Makefile $(docdir)/scripts/Makefile
	@scripts/update_file ./Makefile.in $(docdir)/scripts/Makefile.in
	@scripts/update_file ./macros $(docdir)/scripts/macros
	@scripts/update_file ./scripts/update_module_file $(docdir)/scripts/update_module_file
	@scripts/update_file ./scripts/make_deps.perl $(docdir)/scripts/make_deps.perl
	@scripts/update_file ./scripts/make_dist $(docdir)/scripts/make_dist
	@scripts/update_file ./scripts/make_navbar $(docdir)/scripts/make_navbar
	@scripts/update_file ./scripts/update_file $(docdir)/scripts/update_file
	@scripts/update_file ./scripts/foo.perl $(docdir)/scripts/foo.perl
	@scripts/update_file ./scripts/foo2html.perl $(docdir)/scripts/foo2html.perl

TONTO-nav-bar.html : Makefile
	./scripts/make_navbar $(sort $(basename $(htmlfiles))) > \
          $(docdir)/TONTO-nav-bar.html

#------------------------------------------------------------------------------
# >>> Main dependency rules file
#
# The "make_deps" script scans all the .foo files to make a .dep file, which
# contains the dependent modules USE'd by the .foo file. These .dep files are
# placed in the "dependencies" directory and are combined together to form the
# main "dependfile" makefile.
#------------------------------------------------------------------------------

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),distclean)
ifneq ($(MAKECMDGOALS),docsclean)
ifneq ($(MAKECMDGOALS),distribution)
ifneq ($(MAKECMDGOALS),dependfile)
ifneq ($(MAKECMDGOALS),documentation)
include ./dependfile
endif
endif
endif
endif
endif
endif

dependfile : $(dependfiles)
	@if (! -e ./dependencies)  mkdir ./dependencies
	perl -pe "s/f90/$(F90SUFFIX)/go;" $(addprefix ./dependencies/, $(dependfiles)) \
          > ./dependfile

#------------------------------------------------------------------------------
# >>> Default (implicit) suffix rules
#
# See the discussion in the "make_deps.perl" script for an idea of
# how this works.
#------------------------------------------------------------------------------

%.dep : %.foo make_deps.perl
	@if (! -e dependencies)  mkdir dependencies
	perl -w scripts/make_deps.perl foofiles/$(*F).foo dependencies/$(*F).dep

types.$(F90SUFFIX) : types.foo foo.perl
	@if (! -d f90)           mkdir f90
	@if (! -d interfaces)    mkdir interfaces
	perl -w scripts/foo.perl foofiles/$(<F) f90/$(*F).$(F90SUFFIX) interfaces/$(*F).int

%.$(F90SUFFIX) : %.foo foo.perl types.mod
	@if (! -d f90)           mkdir f90
	@if (! -d interfaces)    mkdir interfaces
	perl -w scripts/foo.perl foofiles/$(<F) f90/$(*F).$(F90SUFFIX) interfaces/$(*F).int

%.html : %.foo foo2html.perl types.foo foo.perl
	@if (! -d $(docdir)/htmlfiles) mkdir $(docdir)/htmlfiles
	@if (! -d $(docdir)/f90files)  mkdir $(docdir)/f90files
	@if (! -d $(docdir)/foofiles)  mkdir $(docdir)/foofiles
	perl -w scripts/foo2html.perl foofiles/$(<F) $(docdir)/htmlfiles/$(*F).html $(docdir)/htmlfiles/$(*F)_short.html
	perl -w scripts/foo.perl foofiles/$(<F) $(docdir)/f90files/$(*F).$(F90SUFFIX) $(docdir)/f90files/$(*F).int
	cp -f foofiles/$(*F).foo $(docdir)/foofiles

%.mod : 
	make $(*F).o

%.o : %.$(F90SUFFIX) macros Makefile
	@if (! -d objects)       mkdir objects
	@if (! -d modules)       mkdir modules
	@if (! -d new_modules)   mkdir new_modules
	f95 $(FFLAGS) $(F90)   -c -o objects/$(*F).o f90/$(<F)
	scripts/update_module_file $(*F).mod

%.x : %.$(F90SUFFIX) macros Makefile
	make $($(*F))
	f95 $(FFLAGS) $(F90)   -o $@ $(addprefix objects/, $(notdir $(filter %.o, $^))) f90/$(<F) -lblas -llapack 
	@if (-e $(*F).o) mv -f $(*F).o objects


#------------------------------------------------------------------------------
# Special rule for optimised run_mol.x. Usually breaks the compiler.
#------------------------------------------------------------------------------
#
#run_mol.x : $(f90files) macros Makefile
#	f95 $(FFLAGS) $(F90) -o run_mol.x $(addprefix f90/, $(f90files))
