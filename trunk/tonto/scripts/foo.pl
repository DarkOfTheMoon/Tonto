#!/usr/bin/perl
#-------------------------------------------------------------------------------
#
# foo.perl
#
# Synopsis :
#
#   This script is used to convert foo files into other formats.  It can output
#   to standard compliant Fortran 95 code, and/or produce HTML documentation.
#
# Usage :
# 
# perl -w ./foo.pl  [ -fortran file.f95 [-fortran_int file.int] [-fortran_use file.use] ]
#                   [-html_short short.html -html_long long.html] [-types types.foo] 
#                   [-routine_calls file.rcf] [-used_routines file.usd]
#                   [-stack] [-timer] [-no_generic] [-no_unknown] [-no_system] [-tidy]
#                   [dir/]file.foo
# 
# Where :
# 
# [dir/]file.foo           is the foo file to be preprocessed. The .foo extension
#                          is required.  Also, "file" must be the lower case name
#                          of any module or program defined in "file.foo". If
#                          "dir/" is present, then the directory "dir" is used to
#                          find any required inherited foo modules.
# 
# -fortran file.f95        is the generated fortran90+ file.
# 
# -fortran_int file.int    is the generated fortran90+ generic interface file; if
#                          not supplied and -fortran supplied, defaults to "file.int" 
#                          where "file" is the head part of argument "file.foo". 
#                          Note that -fortran must be supplied.
# 
# -fortran_use file.use    is the generated fortran90+ USE file; if not supplied
#                          and -fortran is supplied, defaults to "file.int" where
#                          "file" is the head part of argument "file.foo". Note
#                          that -fortran must be supplied.
# 
# -types types.foo         specifies the foo types file, containing all type
#                          definitions; if not supplied, defaults to "dir/types.foo" 
#                          where "dir" is the directory head for the foo file.
# 
# -html_long long.html     specifies the name of the long version of the HTML
#                          documentation to be produced.
# 
# -html_short short.html   specifies the name of the short version of the HTML
#                          documentation to be produced.  Note that both -html_long 
#                          and -htmlshort must be given in order to produce HTML 
#                          documentation.
#
# -stack                   specifies that STACK, UNSTACK and CHECK macros will be 
#                          outputted in the generated fortran source. These macros 
#                          are usually defined in the "macros" file.  
#
# -timer                   specifies that START_TIMER and STOP_TIMER macros are
#                          outputted in the generated fortran source.
#
# -no_generic              specifies that no or fewer generic interfaces will be
#                          used, by appending the name of the module to the
#                          routine name, so that it becomes unique. This option
#                          will normally lead to routine names longer than 31
#                          characters which is not standard F95. However, the
#                          names should be less than 63 characters so it should
#                          be standard F03.
#
# -no_unknown              specifies that the UNKNOWN macro *not* be expanded to 
#                          display a list of all allowed case options, which is 
#                          useful for avoiding calls to the SYSTEM module.
#
# -no_system               specifies that the SYSTEM module *not* be used by
#                          default, in the outputted fortran source.
#
#                       
# -tidy                    specfies that a tidied up version of file.foo,
#                          called "file.tidy", will be produced. The tidied
#                          file has the recommended 3 space indent, and ENSURE
#                          macros are placed before local variable declarations.
#
# -routine_calls file.rcf  specifies that the calls from each routine are to be 
#                          outputted to file.rcf, for later use in compactification, 
#                          by an associated script compactify_calls.pl
#
# -used_routines file.usd  specifies a .usd file which lists the routines which are 
#                          to be compiled. If the file does not exist, then none of 
#                          the routines are compiled.
#
# (c) Dylan Jayatilaka, Daniel Grimwood, University of Western Australia, 2005
#
# $Id$
#-------------------------------------------------------------------------------

use English;            # Get rid of horrible Perl short forms
use File::Spec ('splitpath','catpath');
use strict;             # Make sure the scope of all variables is declared.

$INPUT_RECORD_SEPARATOR  = "\n";
$OUTPUT_FIELD_SEPARATOR  = ' ';
$OUTPUT_RECORD_SEPARATOR = "\n";

################################################################################
#                               File names and handles
#

my $typesfile = "";           # The types.foo file
my $foofile = "";             # The required .foo file to work on
my $getfile = "";             # The inheritance file.
my $fortranfile = "";         # The .fortran file produced
my $fortranintfile = "";      # The .int file produced
my $fortranusefile = "";      # The .use file produced
my $routcallfile= "";         # The .rcf file produced
my $usdfile = "";             # The .usd file produced, for eliminating unused routines
my $htmlshortfile = "";       # This is the short .html file produced
my $htmllongfile  = "";       # This is the long .html file produced
my $tidyfile = "";            # The tidied up foo file
my $HTMLSHORTHANDLE;
my $HTMLLONGHANDLE;
my $foohandle;
my $oldhandle;
my @filestack = ();
my %filelinenum = ();
my %filename = ();

my $foofile_head_name;        # First part of foofile name
my $foofile_tail_name;        # Tail of foofile, should be .foo
my $foofile_volume;           # .foo file volume
my $foofile_directory;        # .foo file directory

my $do_fortran = 0;           # Translate to fortran
my $do_html = 0;              # Translate to HTML
my $do_inherit = 0;           # Whether to follow inheritance inclusion
my $do_stack = 0;             # Set TRUE if STACK/UNSTACK macros are to be made
my $do_timer = 0;             # Set TRUE if START_TIMER/STOP_TIMER macros are to be made
my $do_unknown = 1;           # Set TRUE if UNKNOWN construct is made
my $do_generic = 1;           # Set TRUE if generic interfaces are to be used
my $do_system  = 1;           # Set TRUE if SYSTEM module is always to be used
my $do_routine_calls = 0;     # Set TRUE if routine calls are to be stored
my $do_tidy    = 0;           # Set TRUE if preprocessor will tidy code
my $do_usd = 0;               # Set TRUE if eliminatinmg unused routines AND the .usd file exists 

################################################################################
#                                Scoping units.
#
my $scopeunit = '';           # The current scoping unit AFTER this line.
my $oldscopeunit = '';        # The previous scoping unit BEFORE this line.
my $newscopeunit = '';        # The scoping unit *descriptor* AFTER the current line -- IF ANY
my $parentscope  = '';        # the enclosing parent scoping unit AFTER this line.
my $newscopeunitfound = 0;    # TRUE if a new scoping unit is on this line.
my @scope = undef;            # The nested list of current scoping units.

################################################################################
my %called_routines;          # The Tonto module name, and fortran name of called routines.
my %usd;                      # The list of used routines.
my %routine_calls;            # The list of routine calls for each routine
my %used_modules;             # The list of variables types used NOTENECESARILY method-called
my %function_res_type;        # Types of function results.
my %tonto_type;               # All types defined in $typesfile AND the types of their components
my %module_type;              # All types defined within the module, *not* $typesfile, AND components
my %tonto_type_info;          # Information about each tonto type WITHOUT all component info
my @tonto_intrinsic_scalar_type_names; # The tonto names STR, INT, BIN, etc ...
my @tonto_intrinsic_array_type_names;  # The tonto names for 1,2,...,7 dimension arrays
my @tonto_intrinsic_functions; # Intrinsic routines in Tonto.
my @all_known_type_names;
my %tonto_assumed_array_part; # Assumed array subroutine argument substitutions
my %global_var_info;          # Type (and other) information of all GLOBALLY available variables.
my %local_var_info;           # Type (and other) information of all LOCALLY available variables.

my $input_line;               # The current input line to be processed
my $inherit_string;           # The inherit string used to find a matching interface
my $fortran_out;
my $skip_fortran_out;
my $html_out;
my $skip_html_out;
my $html_do_indent;           # Do a HTML indent: else, case scopes are not handled properly yet.
my $tidy_out;
my $skip_tidy_out;

my $module_name;              # The name of the current module/type
my $module_full_name;         # The name of the current module/type with dotted part
my $module_fort_type;         # Fortran module name -- without submodule part
my $module_fort_name;         # Fortran module name, for USE statements
my $module_self_decl;         # Fortran module name for :: self declarations
my $module_head_name;         # Fortran module head name for array types
my $module_is_intrinsic;      # True if the module is of intrinsic type
my $module_is_array;          # True if themodule is of array type
my $module_is_virtual;        # True if the module is virtual
my %module;                   # Module attributes hash.
my $n_type_args = 0;          # The number of type argumets for this module
my @type_arg;                 # This list of type arguments -- and arguments of arguments!
my $n_inherited_type_args = 0;# The number of INHERITED type argumets for this module
my @inherited_type_arg;       # This list of INHERITED type arguments -- and arguments of arguments!
my $n_define_type;
my @old_define_type;          # Explicitly define type substitutions (also non-type substitutions).
my @new_define_type;          # 
my @old_expand_type;          # Explicitly define type substitutions (also non-type substitutions).
my @new_expand_type;          # 

my $name;
my %linenum;                  # line nummber for each filehandle.
my $not_blank;
my %case;
my $is_program = 0;
my $n_case_opt;
my $pass;                    # The number of passes through file
my %routine;                 # Routine attributes hash.
my %first_overload_count;    # Routine overload count from 1st pass.
my %overload_count;          # Routine overload count.
my $current_rout_name;
my @rout_name_stack;
my $current_type_name;       # The type of the last variable declared
my $module_type_name;        # The type of the last module type declaration

#
my $html_synopsis_found = 0;
my $html_GNU_found = 0;

my $debug = 0;

## -----------------------------------------------------------------------------
## Hack some function return values. This should be done properly by writing
## this kind of info to file, as the foo code is processed.
## -----------------------------------------------------------------------------

$function_res_type{"INT_to_str"} = 'STR';
$function_res_type{"INT_factorial"} = 'REAL';
$function_res_type{"INT_double_factorial"} = 'REAL';
$function_res_type{"REAL_to_str"} = 'STR';

## -----------------------------------------------------------------------------
## Set up some tonto type information, including array substitution information
## -----------------------------------------------------------------------------

@tonto_intrinsic_functions = (
    'abs',
    'acos',
    'allocated',
    'asin',
    'associated',
    'atan',
    'cos',
    'mod',
    'modulo',
    'nullify',
    'scan',
    'sin',
    'size',
    'tan',
    'trim',
    'verify'
);

@tonto_intrinsic_scalar_type_names = ( # Tonto intrinsic scalar type names
    'STR',
    'BIN',
    'BIN{1}',
    'BIN{4}',
    'INT',
    'INT{1}',
    'INT{2}',
    'INT{4}',
    'INT{8}',
    'REAL',
    'REAL{4}',
    'REAL{8}',
    'REAL{16}',
    'CPX',
    'CPX{4}',
    'CPX{8}',
    'CPX{16}',
);

@tonto_intrinsic_array_type_names = (  # Tonto names for arrays of different dimensions 
    '???',                   # 0
    'VEC',                   # 1
    'MAT',                   # 2
    'MAT3',                  # 3
    'MAT4',                  # 4
    'MAT5',                  # 5
    'MAT6',                  # 6
    'MAT7',                  # 7
);

%tonto_assumed_array_part = (          # Assumed array dummy argument substitutions 
    'VEC'      => ':',
    'MAT'      => ':,:',
    'MAT3'     => ':,:,:',
    'MAT4'     => ':,:,:,:',
    'MAT5'     => ':,:,:,:,:',
    'MAT6'     => ':,:,:,:,:,:',
    'MAT7'     => ':,:,:,:,:,:,:',
);
                                       # Make Tonto intrinsic scalar & array information
                                       # WARNING: ARR{STR} element sizes are special
my ($scalar_type,$elt_size,$elt_1,$head_name,$array_type);
@all_known_type_names = @tonto_intrinsic_scalar_type_names;
foreach $scalar_type (@tonto_intrinsic_scalar_type_names) {
   $elt_size = $scalar_type . "_SIZE";
   %{$tonto_type_info{$scalar_type}} = &analyse_type_name($scalar_type);
   $tonto_type_info{$scalar_type}{tonto_size} = $scalar_type . "_SIZE";
   foreach $head_name (keys %tonto_assumed_array_part) {
      $array_type = "$head_name\{$scalar_type\}";
      %{$tonto_type_info{$array_type}} = &analyse_type_name($array_type);
      if ($scalar_type eq 'STR') {
         $elt_1 = $tonto_assumed_array_part{$head_name} ;
         $elt_1 =~ s/:/1/g;
         $tonto_type_info{$array_type}{tonto_element_size} = "len(self(" . $elt_1 . "))*CHR_SIZE"; 
      } else {
         $tonto_type_info{$array_type}{tonto_element_size} = $elt_size;
      }
      push(@all_known_type_names,$array_type);
   }
}
                                       # Add a few ad hoc
$scalar_type = 'TYPES';
%{$tonto_type_info{$scalar_type}} = &analyse_type_name($scalar_type);
$tonto_type_info{$scalar_type}{tonto_size} = "???";
$array_type = 'VEC{VEC{REAL}}';
%{$tonto_type_info{$array_type}} = &analyse_type_name($array_type);
$tonto_type_info{$array_type}{tonto_element_size} = "???";

push(@all_known_type_names,$array_type);

## -----------------------------------------------------------------------------
## Define Tonto global variable symbol table hashes
## -----------------------------------------------------------------------------

%{$global_var_info{tonto}}    = &analyse_type_name('SYSTEM');
%{$global_var_info{stdin}}    = &analyse_type_name('TEXTFILE');
%{$global_var_info{stdout}}   = &analyse_type_name('TEXTFILE');
%{$global_var_info{stderr}}   = &analyse_type_name('TEXTFILE');
%{$global_var_info{std_time}} = &analyse_type_name('TIME');
%{$global_var_info{tonto_parallel}} = &analyse_type_name('PARALLEL');

%local_var_info = %global_var_info;



#################################################################################
## >>>>> START START START START
#################################################################################

&analyse_command_arguments(@ARGV); # <------------- Analyse command arguments

&analyse_types_file;               # <------------- Analyse the types.foo file

$pass = 1;
open(FOOFILE, $foofile);           # FIRST PASS: loop over the .foo file lines 
&start_foofile(*FOOFILE,$foofile); # and get the procedure interfaces.
&start_foofile_scopes;             # Initialize scope information

$do_inherit = 1;                   # Do not follow get_from directives

LINE: while (<$foohandle>) {       # Loop over .foo lines
    $filelinenum{$foohandle}++;
    &analyse_foo_line;
    last if ($module_is_virtual && ! $do_tidy);
}

&end_foofile;
close FOOFILE;

#print "Second pass ...";
$pass = 2;
open(FOOFILE, $foofile);           # SECOND PASS: Loop over the .foo file lines 
if ($do_routine_calls) { open(RCFILE, ">$routcallfile"); }
&start_foofile(*FOOFILE,$foofile); # and get the procedure interfaces.
#$foohandle  = *FOOFILE;            # and generate the fortran/HTML lines
#$oldhandle  = $foohandle;

if ($do_html)    { &html_start;    }
if ($do_fortran) { &fortran_start; }
if ($do_tidy)    { &tidy_start;    }

&start_foofile_scopes;             # Initialize scope information

LINE: while (<$foohandle>) {       # Loop over .foo lines
    $filelinenum{$foohandle}++;
    &analyse_foo_line;
    &process_foo_line; 
    last if ($module_is_virtual && ! $do_tidy);
}

if ($do_fortran) { &fortran_end; }
if ($do_html)    { &html_end;    }
if ($do_tidy)    { &tidy_end;    }
close FOOFILE;                     # All done
if ($do_routine_calls) { close RCFILE; }

#################################################################################
## >>>>> END END END END END END
#################################################################################



################################################################################
########################################## Routines ############################
################################################################################

###############################################################################
# Analyse argument list for .fortran, .int, .use, types.foo and file.foo files
# And check that everything is OK, as far as possible.

sub analyse_command_arguments {

   my ($arg,$argerr);
   $argerr=0;
   $argerr=1 if (@_==0);
   
   # Extract the command line arguments

   while (@_) {
       $arg = shift;
       $_ = $arg;
       if (/^-/) {
           /^-types\b/          && do { $typesfile      = shift; next; };
           /^-fortran\b/        && do { $fortranfile    = shift; next; };
           /^-fortran_int\b/    && do { $fortranintfile = shift; next; };
           /^-fortran_use\b/    && do { $fortranusefile = shift; next; };
           /^-html_short\b/     && do { $htmlshortfile  = shift; next; };
           /^-html_long\b/      && do { $htmllongfile   = shift; next; };
           /^-generic\b/        && do { $do_generic     = 1;     next; };
           /^-no_generic\b/     && do { $do_generic     = 0;     next; };
           /^-stack\b/          && do { $do_stack       = 1;     next; };
           /^-no_stack\b/       && do { $do_stack       = 0;     next; };
           /^-timer\b/          && do { $do_timer       = 1;     next; };
           /^-no_timer\b/       && do { $do_timer       = 0;     next; };
           /^-unknown\b/        && do { $do_unknown     = 1;     next; };
           /^-no_unknown\b/     && do { $do_unknown     = 0;     next; };
           /^-system\b/         && do { $do_system      = 1;     next; };
           /^-no_system\b/      && do { $do_system      = 0;     next; };
           /^-routine_calls\b/  && do { $routcallfile   = shift; next; };
           /^-used_routines\b/  && do { $usdfile        = shift; next; };
           /^-tidy\b/           && do { $do_tidy        = 1;     next; };
           warn "\n Error : unexpected argument $arg\n";
           $argerr=1;
           goto ERROR;
       }
       $foofile = $arg;
       if (@_ > 0) {
           warn "\n Error : more than one foo file specified, @ARGV\n";
           $argerr=1;
           goto ERROR;
       }
   }
   
   # Analyse the command line arguments

   if ($htmllongfile ne "" || $htmlshortfile ne "") { $do_html = 1 };

   if ($fortranfile ne "") { $do_fortran=1 };

   if (! $do_fortran && ! $do_html && ! $do_tidy ) {
           warn "\n Error : must specify one of -fortran, -html_short, -html_long, -tidy\n @ARGV\n";
           $argerr=1;
           goto ERROR;
   }
   
   $foofile   =~ /([\w{,}]+)(\.\w+)*?(\.foo)?$/;
   $foofile_head_name = '' ;
   if (defined $1) { $foofile_head_name = $1 } 
   if (defined $2) { $foofile_head_name .= $2 } 
   $foofile_tail_name = '';
   if (defined $3) { $foofile_tail_name = $3; }

   if ($foofile_head_name eq "") {
           warn "\n Error : no head part for file.foo\n";
           $argerr=1;
           goto ERROR;
   }
   if ($foofile_tail_name eq "") {
           warn "\n Error : tail of file.foo does not end in .foo\n";
           $argerr=1;
           goto ERROR;
   }
   
   my $file;
   ($foofile_volume,$foofile_directory,$file) = File::Spec->splitpath($foofile);
   
   if ($do_fortran) {
      if ($fortranintfile eq "") { $fortranintfile = $foofile_head_name . ".int"; }
      if ($fortranusefile eq "") { $fortranusefile = $foofile_head_name . ".use"; }
   } else {
      if ($fortranintfile ne '' || $fortranusefile ne '') {
           warn "\n Error : must specify -fortran option";
           $argerr=1;
           goto ERROR;
      }
   }
   
   if ($typesfile eq "") { 
      $typesfile = File::Spec->catpath($foofile_volume,$foofile_directory,"types.foo"); 
   }
   
   if (! open(FOOFILE, $foofile)) {
           warn "\n Error : foofile \"$foofile\" does not exist";
           $argerr=1;
           goto ERROR;
   }
   close FOOFILE;
   if (! open(TYPESFILE,$typesfile)) {
           warn "\n Error : type file \"$typesfile\" does not exist";
           $argerr=1;
           goto ERROR;
   }
   close TYPESFILE;

   if ($do_tidy) {
      $tidyfile = $foofile_head_name.'.tidy';
   }

   if ($routcallfile ne "") {
      $do_routine_calls = 1;
   }

   if ($usdfile ne "") {
      $do_usd = 1;
      if (open(USDFILE,$usdfile)) {
         my $rout;
         while ($rout = <USDFILE>) {
            chomp($rout);
            $usd{$rout} = 1;
            print "keeping $rout";
         }
         close USDFILE;
      } else {
      #  $do_usd = 0;
      }
   }
   
   return if ($argerr==0);

   ERROR: ;

   # A command line argument error occured ... given them the full info.

   print << '-----EOF';
   
   Usage :
 
   perl -w ./foo.pl  [ -fortran file.f95 [-fortran_int file.int] [-fortran_use file.use] ]
 
                     [-html_short short.html -html_long long.html] [-types types.foo] 
 
                     [-routine_calls file.rcf] [-used_routines file.usd]

                     [-stack] [-timer] [-no_generic] [-no_unknown] [-no_system] [-tidy]
 
                     [dir/]file.foo
   
   Where :
   
   [dir/]file.foo           is the foo file to be preprocessed. The .foo extension
                            is required.  Also, "file" must be the lower case name
                            of any module or program defined in "file.foo". If
                            "dir/" is present, then the directory "dir" is used to
                            find any required inherited foo modules.
   
   -fortran file.f95        is the generated fortran90+ file.
   
   -fortran_int file.int    is the generated fortran90+ generic interface file; if
                            not supplied and -fortran supplied, defaults to "file.int" 
                            where "file" is the head part of argument "file.foo". 
                            Note that -fortran must be supplied.
   
   -fortran_use file.use    is the generated fortran90+ USE file; if not supplied
                            and -fortran is supplied, defaults to "file.int" where
                            "file" is the head part of argument "file.foo". Note
                            that -fortran must be supplied.
   
   -types types.foo         specifies the foo types file, containing all type
                            definitions; if not supplied, defaults to "dir/types.foo" 
                            where "dir" is the directory head for the foo file.
   
   -html_long long.html     specifies the name of the long version of the HTML
                            documentation to be produced.
   
   -html_short short.html   specifies the name of the short version of the HTML
                            documentation to be produced.  Note that both -html_long 
                            and -htmlshort must be given in order to produce HTML 
                            documentation.

   -stack                   specifies that STACK, UNSTACK and CHECK macros will be 
                            outputted in the generated fortran source. These macros 
                            are usually defined in the "macros" file.  

   -timer                   specifies that START_TIMER and STOP_TIMER macros are
                            outputted in the generated fortran source.

   -no_generic              specifies that no or fewer generic interfaces will be
                            used, by appending the name of the module to the
                            routine name, so that it becomes unique. This option
                            will normally lead to routine names longer than 31
                            characters which is not standard F95. However, the
                            names should be less than 63 characters so it should
                            be standard F03.

   -no_unknown              specifies that the UNKNOWN macro *not* be expanded to 
                            display a list of all allowed case options, which is 
                            useful for avoiding calls to the SYSTEM module.

   -no_system               specifies that the SYSTEM module *not* be used by
                            default, in the outputted fortran source.

                         
   -tidy                    specfies that a tidied up version of file.foo,
                            called "file.tidy", will be produced. The tidied
                            file has the recommended 3 space indent, and ENSURE
                            macros are placed before local variable declarations.

   -routine_calls file.rcf  specifies that the calls from each routine are to be 
                            outputted to file.rcf, for later use in compactification, 
                            by an associated script compactify_calls.pl

   -used_routines file.usd  specifies a .usd file which lists the routines which are 
                            to be compiled. If the file does not exist, then none of 
                            the routines are compiled.
-----EOF
     exit 1;
}

################################################################################
## Analyse the types.foo file (i.e. $typesfile) for the components of all types

sub analyse_types_file {

   my ($X,$type_name,$tmp);

   open(TYPESFILE,$typesfile);
   
   # Search for a type line

   while ($X = <TYPESFILE>) {

       chop($X) if (defined $X);

       last if ($X =~ '^\s+end(?:\s+|$|!)' );             # End of types.foo
       next if ($X =~ '^\s*!' );                          # Comment
       next if ($X !~ '\s+type +([A-Z][\w{,}.]*)');       # Look for next type definition

       $tmp = $1;
       $type_name = uc($tmp);

       # Analyse the type here #####################
       %{$tonto_type_info{$type_name}} = &analyse_type_name($type_name,0);           

       # Autovivify the hash table for this type #######
       $tonto_type{$type_name}{'--exists--'} = 1;
   
       # Analayse the components of the type in the body
       while (chop($X = <TYPESFILE>)) {                    
           last if ($X =~ '^\s+end(?:\s+|$|!)' );         # End of types def
           next if ($X =~ '^\s*!' );                      # Comment
           next if ($X =~ '^\s*$' );                      # Blank
           &analyse_variable_declaration($X,$tonto_type{$type_name});
       }
       delete $tonto_type{$type_name}{'--exists--'};

       &make_tonto_type_size_info($type_name);            # Get size information
       &make_tonto_element_size_info($type_name);         # ... in type order
       push(@all_known_type_names,$type_name);            # Add to type name list

   }
   
   close TYPESFILE;

   # Reverse the order so the more complex types come first
   # This is needed so when substituting type names the more
   # complex array types are substituted first.
   @all_known_type_names = reverse @all_known_type_names;

}

################################################################################
## Construct the tonto_type size information.

sub make_tonto_type_size_info {

   my ($type_name) = @_;

   return if ($tonto_type_info{$type_name}{is_array_type});

   # Attach the size information onto tonto_type_info hash
   my (%info,$size,$typ,$typ_uc,$typ_size); 
   %info = &tonto_size($type_name,\%tonto_type);
   %{$tonto_type_info{$type_name}} = ( %{$tonto_type_info{$type_name}} , %info );

   # Loop over intrinsic types and work out $size macro
   $size = '';
   foreach $typ (keys %info) {
      $typ_size = $info{$typ};
      if ($typ_size != 0) {
         $typ_uc = uc($typ);
         $size = $size . $typ_size . '*' . $typ_uc . '+';
      }
   }
   $size =~ s/[+]$//;
   $tonto_type_info{$type_name}{tonto_size} = $size;
}

################################################################################
# Construct the tonto_element_size information.

sub make_tonto_element_size_info {

   my ($type_name) = @_;

   return if ( ! $tonto_type_info{$type_name}{is_array_type});
   my $type_arg_1 = $tonto_type_info{$type_name}{type_arg}[1];
   if (! defined $tonto_type_info{$type_arg_1}{tonto_size}) {
      &report_error("type \"$type_arg_1\" must be defined before type \"$type_name\".");
   }
   $tonto_type_info{$type_name}{tonto_element_size} = 
      $tonto_type_info{$type_arg_1}{tonto_size};
}

################################################################################
# Get the size of each tonto type (works recursively if needed, but this has
# been disabled in favor of a stored method, which means that this routine must
# be called in order of increasing type complexity).

sub tonto_size {

   my ($type_name,$tonto_type) = @_;

   my ($ptr);
   my ($str,$bstr);
   my ($bin,$bin1,$bin4);
   my ($int,$int1,$int2,$int4,$int8);
   my ($real,$real4,$real8,$real16);
   my ($cpx,$cpx4,$cpx8,$cpx16);

   $ptr = 0;
   $str = 0; $bstr = 0;
   $bin = 0; $bin1 = 0; $bin4 = 0;
   $int = 0; $int1  = 0; $int2 = 0; $int4 = 0; $int8 = 0;
   $real = 0; $real4 = 0; $real8 = 0; $real16 = 0;
   $cpx  = 0; $cpx4 = 0; $cpx8 = 0; $cpx16 = 0;

   my $var;
   foreach $var (keys %{$tonto_type->{$type_name}}) {

      next if ($var =~ /--\w+--/);                          # Skip non-variables summary info

      my $ptr_part   = $tonto_type->{$type_name}{$var}{type_ptr_part};
      my $head_name  = $tonto_type->{$type_name}{$var}{type_head_name};
      my $n_type_arg = $tonto_type->{$type_name}{$var}{n_type_args};
      my $type_arg_1 = $tonto_type->{$type_name}{$var}{type_arg}[1];
      my $type_size  = $tonto_type->{$type_name}{$var}{type_size_part};
      my $var_type   = $tonto_type->{$type_name}{$var}{type_name};
      my $is_intrinsic_type = $tonto_type->{$type_name}{$var}{is_intrinsic_type};
      my $is_array_type = $tonto_type->{$type_name}{$var}{is_array_type};
#print "------type_name = $type_name";
#print "line     = $input_line";
#print "var      = $var";
#print "ptr_part = $ptr_part",$tonto_type->{$type_name}{$var}{type_ptr_part};
#print "size part  = $type_size_part";
#print "intrinsic? = $is_intrinsic_type";
#print "array?    = $is_array_type";

      if    ($ptr_part eq '*')           { $ptr++; }           # Pointer

      elsif ($is_intrinsic_type) { 
         if    ($type_size =~ 'BSTR')    { $bstr++; }
         elsif ($var_type eq 'STR')      { $str++; }           # These are intrinsic types
         elsif ($var_type eq 'BIN')      { $bin++; }
         elsif ($var_type eq 'INT')      { $int++; }
         elsif ($var_type eq 'REAL')     { $real++; }
         elsif ($var_type eq 'CPX')      { $cpx++; }
         elsif ($var_type eq 'INT{1}')   { $int1++; }
         elsif ($var_type eq 'INT{2}')   { $int2++; }
         elsif ($var_type eq 'INT{4}')   { $int4++; }
         elsif ($var_type eq 'INT{8}')   { $int8++; }
         elsif ($var_type eq 'BIN{1}')   { $bin1++; }
         elsif ($var_type eq 'BIN{4}')   { $bin4++; }
         elsif ($var_type eq 'REAL{4}')  { $real4++; }
         elsif ($var_type eq 'REAL{8}')  { $real8++; }
         elsif ($var_type eq 'REAL{16}') { $real16++; }
         elsif ($var_type eq 'CPX{4}')   { $cpx4++; }
         elsif ($var_type eq 'CPX{8}')   { $cpx8++; }
         elsif ($var_type eq 'CPX{16}')  { $cpx16++; }
      }

      elsif (! $is_array_type) {                                # Non array derived type
#print "***calling recursively***";
#         my ($new_name,%info);
#         $new_name = $tonto_type->{$type_name}{$var}{type_name};
#         %info = &tonto_size($new_name,$tonto_type);
#print "***return  recursively***";
            if (! defined $tonto_type_info{$var_type}) {
               &report_error("type \"$var_type\" must be defined before type" .
               " \"$type_name\" in \"$typesfile\".");
            }
            $ptr    += $tonto_type_info{$var_type}{ptr_size};
            $str    += $tonto_type_info{$var_type}{str_size};
            $bstr   += $tonto_type_info{$var_type}{bstr_size};
            $bin    += $tonto_type_info{$var_type}{bin_size};
            $bin1   += $tonto_type_info{$var_type}{bin1_size};
            $bin4   += $tonto_type_info{$var_type}{bin4_size};
            $int    += $tonto_type_info{$var_type}{int_size};
            $int1   += $tonto_type_info{$var_type}{int1_size};
            $int4   += $tonto_type_info{$var_type}{int4_size};
            $int8   += $tonto_type_info{$var_type}{int8_size};
            $real   += $tonto_type_info{$var_type}{real_size};
            $real4  += $tonto_type_info{$var_type}{real4_size};
            $real8  += $tonto_type_info{$var_type}{real8_size};
            $real16 += $tonto_type_info{$var_type}{real16_size};
            $cpx    += $tonto_type_info{$var_type}{cpx_size}; 
            $cpx4   += $tonto_type_info{$var_type}{cpx4_size}; 
            $cpx8   += $tonto_type_info{$var_type}{cpx8_size}; 
            $cpx16  += $tonto_type_info{$var_type}{cpx16_size}; 
      }

      elsif ($is_array_type && $type_size ne '') {               # ARRAY types with explicit size
         my $size = &fortran_size($type_size);
#print ">>>>>>>>>>>>> type_size  = $type_size";
#print ">>>>>>>>>>>>> size       = $size";
#print "line     = $input_line";
#print "var      = $var";
         if    ($type_size  =~ 'BSTR')     { $bstr   += $size; }
         elsif ($type_arg_1 eq 'STR')      { $str    += $size; } # These are intrinsic array types
         elsif ($type_arg_1 eq 'BIN')      { $bin    += $size; }
         elsif ($type_arg_1 eq 'INT')      { $int    += $size; }
         elsif ($type_arg_1 eq 'REAL')     { $real   += $size; }
         elsif ($type_arg_1 eq 'CPX')      { $cpx    += $size; }
         elsif ($type_arg_1 eq 'INT{1}')   { $int1   += $size; }
         elsif ($type_arg_1 eq 'INT{2}')   { $int2   += $size; }
         elsif ($type_arg_1 eq 'INT{4}')   { $int4   += $size; }
         elsif ($type_arg_1 eq 'INT{8}')   { $int8   += $size; }
         elsif ($type_arg_1 eq 'BIN{1}')   { $bin1   += $size; }
         elsif ($type_arg_1 eq 'BIN{4}')   { $bin4   += $size; }
         elsif ($type_arg_1 eq 'REAL{4}')  { $real4  += $size; }
         elsif ($type_arg_1 eq 'REAL{8}')  { $real8  += $size; }
         elsif ($type_arg_1 eq 'REAL{16}') { $real16 += $size; }
         elsif ($type_arg_1 eq 'CPX{4}')   { $cpx4   += $size; }
         elsif ($type_arg_1 eq 'CPX{8}')   { $cpx8   += $size; }
         elsif ($type_arg_1 eq 'CPX{16}')  { $cpx16  += $size; }

         else {                                                  # This is a derived array type
            $ptr    += $size * $tonto_type_info{$type_arg_1}{ptr_size};
            $str    += $size * $tonto_type_info{$type_arg_1}{str_size};
            $bstr   += $size * $tonto_type_info{$type_arg_1}{bstr_size};
            $bin    += $size * $tonto_type_info{$type_arg_1}{bin_size};
            $bin1   += $size * $tonto_type_info{$type_arg_1}{bin1_size};
            $bin4   += $size * $tonto_type_info{$type_arg_1}{bin4_size};
            $int    += $size * $tonto_type_info{$type_arg_1}{int_size};
            $int1   += $size * $tonto_type_info{$type_arg_1}{int1_size};
            $int4   += $size * $tonto_type_info{$type_arg_1}{int4_size};
            $int8   += $size * $tonto_type_info{$type_arg_1}{int8_size};
            $real   += $size * $tonto_type_info{$type_arg_1}{real_size};
            $real4  += $size * $tonto_type_info{$type_arg_1}{real4_size};
            $real8  += $size * $tonto_type_info{$type_arg_1}{real8_size};
            $real16 += $size * $tonto_type_info{$type_arg_1}{real16_size};
            $cpx    += $size * $tonto_type_info{$type_arg_1}{cpx_size}; 
            $cpx4   += $size * $tonto_type_info{$type_arg_1}{cpx4_size}; 
            $cpx8   += $size * $tonto_type_info{$type_arg_1}{cpx8_size}; 
            $cpx16  += $size * $tonto_type_info{$type_arg_1}{cpx16_size}; 
         }
      }

      else {
         &report_error("do not know how evaluate tonto_size for variable \"$var\"," .
         " type \"$type_name\".");
      }
   }

   my %info;

   $info{ptr_size} = $ptr;

   $info{str_size}  = $str; 
   $info{bstr_size} = $bstr;

   $info{bin_size}  = $bin; 
   $info{bin1_size} = $bin1; 
   $info{bin4_size} = $bin4;

   $info{int_size}  = $int; 
   $info{int1_size} = $int1; 
   $info{int2_size} = $int2; 
   $info{int4_size} = $int4; 
   $info{int8_size} = $int8;

   $info{real_size}   = $real; 
   $info{real4_size}  = $real4; 
   $info{real8_size}  = $real8; 
   $info{real16_size} = $real16;

   $info{cpx_size}   = $cpx; 
   $info{cpx4_size}  = $cpx4; 
   $info{cpx8_size}  = $cpx8; 
   $info{cpx16_size} = $cpx16;

   return (%info);
}

################################################################################
## Get the Fortran size of each tonto type.

sub fortran_size {
   my ($size) = @_;
   my ($len,$first,$last);
   $size =~ s/[(](.*)[)]/$1/;
   return (0) if $1 !~ /\d/;
   $len = 1;
   while ( $size =~ /(\d+):?(\d+)?/g ) {
      if    (defined $2 && $2 ne '') { $first = $1; $last = $2; }
      elsif (defined $1 && $1 ne '') { $first = 1 ; $last = $1; }
      else             { $first = 1 ; $last = 0; } # This should not happen, but set to 0 if it does
      $len = $len*($last-$first+1);
   }
   return ($len);
}


################################################################################
# Analyse a variable declaration line $X and add it to the symbol information
# hash table reference, $var_info. There are four different symbol tables :
# (1) %{$tonto_type{$type_name}} stores type (and other) information for all
#     components $var of the type $type_name, defined in the types.foo file.
#     Info is stored in the hash reference $tonto_type{$type-name}{$var}.
# (2) %{$module_type{$type_name}} is as above, but for type definitions
#     NOT appearing in the types.foo file.
# (3) $global_var_info{$var} stores type (and other) information for any
#     globally defined variables $var such as "self", "stdin", "tonto", etc. 
# (4) %local_var_info{$var} stores type (an other) information for all locally
#     defined variables within a routine or program scope.

sub analyse_variable_declaration {

    my($X,$var_info) = @_;

    my $function_result = '';
    if (defined $pass && $pass==2 &&
        defined $current_rout_name &&
        defined $routine{$current_rout_name}{function_result} ) {
       $function_result = $routine{$current_rout_name}{function_result};
    }

    $current_type_name = undef;

    # Analyse the type declaration line

    if ($X =~ '\s+::\s+([A-Z][\w{,}.()-=+*/:]*[*]?)') {

        my $typ = $1;
        my $dec = $PREMATCH;
        my $post = $POSTMATCH;

        my $last_var_was_arg = undef; # TRUE if $var is a routine arg
        my $one_var_is_res = undef;   # TRUE if one $var is a routine result
        my $true_arg = undef;         # TRUE if $var is an arg but not a result
        my %info; undef %info;
        my $var;

        while ($dec =~ /([a-zA-Z]\w*)/g) {         # Look for the declared variables, repeatedly

            if ($typ eq 'PTR')          { last; }
            if ($typ eq 'IN')           { last; }
            if ($typ eq 'OUT')          { last; }
            if ($typ eq 'INOUT')        { last; }
            if ($typ =~ m/^pointer/i)   { last; }
            if ($typ =~ m/^target/i)    { last; }
            if ($typ =~ m/^save$/i)     { last; }
            if ($typ =~ m/^allocatable$/i) { last; }

            $var = $1;
            if ($var eq 'DEFAULT_NULL') { last; }          
            if ($var eq 'DEFAULT')      { last; }
            if ($var eq 'NULL')         { last; }

            if ($var eq $function_result && 
                defined $module_full_name &&
                defined $current_rout_name) {
              my $typ1 = $typ;
              if ($typ1 =~ m'STR'io) {
                $typ1 =~ s/len=(\d+)//og;
                $typ1 =~ s/[(][)]//o;
              }

              $function_res_type{"${module_full_name}_${current_rout_name}"} = $typ1;
            }

            # Check if all args are routine arguments, or all aren't
            if ($scopeunit eq 'function' ||
                $scopeunit eq 'subroutine') {
               if (&routine_has_arg($var) == 1) {
                  if (defined $current_rout_name &&
                      defined $routine{$current_rout_name}{in_routine_body} &&
                      $routine{$current_rout_name}{in_routine_body} == 1) {
                    &report_error("variable declared in routine body!\n\n$X");
                  }
                  if ($routine{$current_rout_name}{found_local_var_decl}) {
                     &report_error("declare all routine arguments before local variables:\n\n$X");
                  }
                  if (defined $last_var_was_arg && $last_var_was_arg == 0) {
                     &report_error("not all variables in the one declaration" .
                            "are routine arguments:\n\n$X");
                  }
                  if ($var eq $function_result) {
                     $one_var_is_res = 1;
                     $true_arg = 0;
                  } else {
                     $true_arg = 1;
                  }
                  $last_var_was_arg = 1; # Yes, this was a routine arg
                  $var_info->{$var}{is_routine_arg} = 1;
               } else {
                  if (defined $last_var_was_arg && $last_var_was_arg == 1) {
                    &report_error("not all variables are routine arguments:\n\n$X");
                  }
                  $last_var_was_arg = 0; # No, this was *not* a routine arg
                  $var_info->{$var}{is_routine_arg} = 0;
                  if (! defined $routine{$current_rout_name}{first_local_var_decl} &&
                      ! defined $routine{$current_rout_name}{found_local_var_decl}) {
                     $routine{$current_rout_name}{first_local_var_decl} = 1; # This undef'd later ...
                     $routine{$current_rout_name}{found_local_var_decl} = 1;
                  }
               }
            }

            # String results must be declared separately.
            if (%info && $one_var_is_res && (
                 $info{type_name} =~ '^STR({.*})?' || 
                ($info{is_array_type} && $info{type_arg}{1} =~ '^STR({.*})?'))) {
               &report_error("declare STR-based function result separate" .
                      " from other variables:\n\n$X");
            }
        
            if (! %info) {                         # Analyse the type here ################
               %info = &analyse_type_name($typ,$true_arg);  
#print "------------------------found $var";
#print "line = $X";
#print "info = ",%info;
               if ($typ eq 'PTR' || $typ eq 'IN' || $typ eq 'INOUT' || $typ eq 'OUT')   {
                 &report_error("attribute \"$typ\" is not a valid type for variable \"$var\".");
               }
               my $type = $info{type_name};
               my $ptrp = $info{type_ptr_part};
               if (! defined $tonto_type_info{$type} && $ptrp eq '') {
                 &report_error("type of \"$var\" was not declared in \"$typesfile\".");
               }
               # Correct any attributes not in the type.
               if ($post =~ /\bprivate\b/ ) { $info{type_is_private} = 1; } 
               else                         { $info{type_is_private} = 0; }
               if ($post =~ /\bPTR\b/ || 
                   $post =~ /\bpointer\b/ ) { $info{type_ptr_part} = '*'}
#if ($post =~ /private/ ) { 
#print "line = $X"; 
#} 
            }

            %{$var_info->{$var}} = %info;          # Type info for *this* $var
            %{$local_var_info{$var}} = %info;

#print "CHECK, X                ",$X;
#print "CHECK, full_type_name   ",$var_info->{$var}{full_type_name};
#print "CHECK, type_name        ",$var_info->{$var}{type_name};
#print "CHECK, sub_type_name    ",$var_info->{$var}{sub_type_name};
#print "CHECK, fortran_type_name",$var_info->{$var}{fortran_type_name};
#print "CHECK, fortran_type_decl",$var_info->{$var}{fortran_type_decl};
#print "CHECK, fortran_mod_name ",$var_info->{$var}{fortran_mod_name};
#print "CHECK, type_head_name   ",$var_info->{$var}{type_head_name};
#print "CHECK, n_type_args      ",$var_info->{$var}{n_type_args};
#print "CHECK, type_arg         ",@{$var_info->{$var}{type_arg}};
#print "CHECK, type_arg 1------>",$var_info->{$var}{type_arg}[1];
#print "CHECK, type_array_part  ",$var_info->{$var}{type_array_part};
#print "CHECK, type_size_part   ",$var_info->{$var}{type_size_part};
#print "CHECK, type_ptr_part    ",$var_info->{$var}{type_ptr_part};
#print "CHECK, is_routine_arg   ",$var_info->{$var}{is_routine_arg};

        }

    }
}


################################################################################
# Analyse a type name

sub analyse_type_name {

  my $full_type_name = shift;    # This could be a module name also
  my $is_routine_arg = shift;    # Is 1 if the declared variable is a routine arg
  if (! defined $is_routine_arg) { $is_routine_arg = 0; }

  my ($type_name,$right,$sub_type_name);
  my ($type_head_name,$type_arg_part);
  my ($type_size_part,$type_array_part,$type_ptr_part,$type_is_private);

  if (! defined $full_type_name) { &report_error("type name unknown."); }

  #$full_type_name =~ '^\s*([A-Z][\w\d{,}()]*[A-Z\d}])'; 
  $full_type_name =~ '^\s*([A-Z][\w\d{,}]*[A-Z\d}])'; 

  $type_name = $1;               # TONTO type name including curlies, but NOT sub type...
  $type_name =~ s/[(][^)]*$//;   # Remove unclosed parentheses at end, if there

  my $tmp = $type_name; 
# $tmp =~ s/\{/\\{/g; $tmp =~ s/\}/\\}/g;
  $full_type_name =~ /^\Q$tmp\E/; 
  $right = $POSTMATCH;           # e.g. 'VEC{REAL}' in 'VEC{REAL}.DYLAN"

  $type_name =~ /^([A-Z][A-Z_0-9]*)([{].*[}])?/;

  $type_head_name = $1;          # Type head, without curlies e.g. VEC in VEC{STR}
  $type_arg_part  = $2;          # These are the curlies e.g.  {STR} in VEC{STR}

  if ($right =~ /^[.]([A-Z][A-Z_0-9]*)/) {
     $sub_type_name = $1;        # Only the subtype/submodule dotted part at end
     $right = $POSTMATCH;        # e.g. 'DYLAN' in 'VEC{REAL}.DYLAN' 
  } else {
     $sub_type_name = '';
  }

  if ($right =~ /^\s*[(](.*)[)]/) {
     $type_size_part  = $1;      # The array size part
     $type_array_part = "($1)";  # e.g.  (size(a)) in VEC{STR}(size(a))
     $right = $POSTMATCH;
     if ($type_head_name eq 'STR' && 
         $type_size_part !~ /len\s*=/) { # ... put len= back in 
         $type_size_part = 'len='.$type_size_part;
         $type_array_part = "($1)"; 
     }
  } else {
     $type_size_part  = ''; 
     $type_array_part = "";  
  }

  if ($right =~ /^\s*[*]/) {
     $type_ptr_part = '*';       # The star at the end, if any
  } else {
     $type_ptr_part = '';
  }

  # Get all the type arguments, if any ...

  my $n_type_args = 0;
  my @type_arg    = undef;

  if (defined $type_arg_part && 
              $type_arg_part =~ /[{](.*)[}]/) {
     my ($n,$type_arg_list);
     $type_arg_list = $1;
     $type_arg[0] = '0';
     if ($type_arg_list !~ '{' &&
         $type_arg_list !~ ',' ) {        # Get the only type arg
        $n = 1;
        $n_type_args = $n;
        $type_arg[$n] = $type_arg_list;  
     } else {                             # Look for multiple type args
        $n = 0;
        my ($left,$middle,$right);
        while ($type_arg_list ne '' ) {
           ($left,$middle,$right) =       # Do type args have type args?
              &split_by_first_curly_brackets($type_arg_list);
           if ($middle ne '') {           # Yes, they do ...
              $n = $n + 1;
              $type_arg[$n] = $left . "{" . $middle . "}"; 
              $right =~ s/^\s*,\s*//; 
              $type_arg_list = $right;
              next;
           } 
           $type_arg_list =~ /^([^,]+)(,|$)/; # No type args ...
           if ($1 ne '') {
              $n = $n + 1;
              $type_arg[$n] = $1; 
              $type_arg_list = $POSTMATCH;
              next;
           }
           &report_error("cannot process type argument part: \"$type_arg_part\".");
        }
        $n_type_args = $n;
     }
  }

  # Extract any len= type argument argument. kind= arguments would also be
  # picked up but I'm not sure how to deal with these yet. Don't forget to
  # reconstruct the full type name!
  if ($n_type_args>0 && $type_arg[1] =~ s/[(](\s*len\s*=\s*)?(.*)[)]//) {
     $type_size_part  = "len=$2" . $type_size_part; 
     $type_array_part = "($type_size_part)";
     $type_name = $type_head_name . 
                  "{" .  join(",",@type_arg[1..$n_type_args]) . "}";
  }
  if ($sub_type_name eq '') { $full_type_name = $type_name; }
  else                      { $full_type_name = "$type_name.$sub_type_name"; }

  my $is_intrinsic_type = &is_intrinsic_scalar_type_name($type_name);

  my $is_array_type = &is_array_head_type_name($type_head_name);

  my ($fortran_type_name,
      $fortran_type_decl,
      $fortran_mod_name, 
      $fortran_self_decl) 
        = &make_fortran_type_declarations($type_name,
                                          $sub_type_name,
                                          $type_size_part,
                                          $type_head_name,
                                          $type_arg[1],
                                          $is_routine_arg,
                                          $is_intrinsic_type,
                                          $is_array_type);

#print "----IN analyse_type_name---------------";
#print "type_name         =",$type_name;
#print "full_type_name    =",$full_type_name;
#print "type_name         =",$type_name;
#print "sub_type_name     =",$sub_type_name;
#print "fortran_type_name =",$fortran_type_name;
#print "fortran_type_decl =",$fortran_type_decl;
#print "fortran_mod_name  =",$fortran_mod_name;
#print "fortran_self_decl =",$fortran_self_decl;
#print "type_head_name    =",$type_head_name;
#print "type_arg_part     =",$type_arg_part;
#print "n_type_args       =",$n_type_args;
#print "type_args         =",@type_arg;
#print "type_array_part   =",$type_array_part;
#print "type_size_part    =",$type_size_part;
#print "type_ptr_part     =",$type_ptr_part;
#print "is_intrinsic_type =",$is_intrinsic_type;
#print "is_array_type     =",$is_array_type;
#print "----end analyse_type_name---------------";

  $current_type_name = $full_type_name;

  my %info;

  $info{full_type_name}    = $full_type_name;    # The type name WITH curlies AND WITH any dotted subtype part
  $info{type_name}         = $type_name;         # The type name WITH curlies WITHOUT any dotted subtype part
  $info{sub_type_name}     = $sub_type_name;     # Just the subtype part --- if any
  $info{fortran_type_name} = $fortran_type_name; # The mangled fortran name, with NO curlies and NO submodule part
  $info{fortran_type_decl} = $fortran_type_decl; # type(BLAH), or STR(len=*), etc. Depends on $is_routine_arg
  $info{fortran_mod_name}  = $fortran_mod_name;  # Mangled fortran name WITH submodule part for USE statements
  $info{fortran_self_decl} = $fortran_self_decl; # Can be VEC(STR(len=*),:) if $is_routine arg
  $info{type_head_name}    = $type_head_name;    # The head name of parameterised types
  $info{type_arg_part}     = $type_arg_part;     # The type arg part INCLUDING curlies around it.
  $info{n_type_args}       = $n_type_args;       # The number of type arguments
  $info{type_arg}          = \@type_arg;         # The list of type arguments
  $info{type_array_part}   = $type_array_part;   # The part giving the dimensions of the array
  $info{type_size_part}    = $type_size_part;    # As above, but without parentheses around
  $info{type_ptr_part}     = $type_ptr_part;     # Is '*' for pointer type declarations, else blank
  $info{is_intrinsic_type} = $is_intrinsic_type; # Is TRUE if intrinsic type (including parameterised kind= types)
  $info{is_array_type}     = $is_array_type;     # Is TRUE for array types
  $info{is_array_type}     = $is_array_type;     # Is TRUE for array types

  return (%info);
}

################################################################################
# Return whether the given $type_name is a tonto intrinsic scalar type name.
sub is_intrinsic_scalar_type_name {
   my  $type_name = $_[0];
   if ($type_name =~ /^STR\b({.*})?/  ||
       $type_name =~ /^BIN\b({.*})?/  ||
       $type_name =~ /^INT\b({.*})?/  ||
       $type_name =~ /^REAL\b({.*})?/ ||
       $type_name =~ /^CPX\b({.*})?/  )   { return 1; }
   else                                 { return 0; }
}

################################################################################
# Return whether the given $type_name is a fortran intrinsic type
sub is_array_head_type_name {
   my  $head_name = $_[0];
   if (! defined $head_name)    { return 0; }
   if ($head_name eq 'VEC'  ||
       $head_name eq 'MAT'  ||
       $head_name eq 'MAT3' ||
       $head_name eq 'MAT4' ||
       $head_name eq 'MAT5' ||
       $head_name eq 'MAT6' ||
       $head_name eq 'MAT7' )   { return 1; }
   else                         { return 0; }
}

sub report_error {
################################################################################
  my $message = $_[0];
  my @tmpstack = @filestack;
  print STDERR "\nFoo Error:";
  while ($#tmpstack>=0) {
    #my $thishandle = pop @tmpstack;
    my $thishandle = shift @tmpstack;
    my $line = $filelinenum{$thishandle};
    my $name = $filename{$thishandle};
    print STDERR "Line $line of file \"$name\".";
  }
  if ($#rout_name_stack>=0) {
    print STDERR "Method \"$current_rout_name\".";
  }
  print STDERR "\n$message\n";
  exit 1;
}

################################################################################
sub start_foofile {

  my $handle = $_[0];
  my $name = $_[1];
  if (defined $foohandle) {$oldhandle = $foohandle;}
  else                    {$oldhandle = '';}
  $foohandle = $handle;
  push @filestack,$foohandle;
  $filelinenum{$foohandle} = 0;
  $filename{$foohandle} = $name;

}

################################################################################
sub end_foofile {
  $filelinenum{$foohandle} = 0;
  $oldhandle = $foohandle;
  pop @filestack;
  $foohandle = $filestack[$#filestack];
}

################################################################################
sub start_foofile_scopes {

  %filelinenum  = ();

  undef @scope;
  $scopeunit    = "";
  $oldscopeunit = "";
  $newscopeunit = "";
  $parentscope  = "";

  %overload_count = ();

  # Keep only a few fields in the %routine hash ...
  my ($name,$ensure,$function,$result);
  foreach $name (keys %routine) {
     $ensure   = $routine{$name}{ensure_statements};
     $function = $routine{$name}{function};
     $result   = $routine{$name}{function_result};
     delete $routine{$name};
     $routine{$name}{ensure_statements} = $ensure;
     $routine{$name}{function} = $function;
     $routine{$name}{function_result} = $result;
  }

  $module_is_virtual = 0; 

  $inherit_string = "";

}

################################################################################
# Analyse a line of foo code, to get all required information. This routine does
# not produce any fortran or HTML output, it just analyses.

sub analyse_foo_line {

   chop;         # strip record separator

   $input_line  = $_;              # Get the line
   my $input_inh = $input_line;    # Keep for inheritance

   $not_blank = ($input_line =~ '^ *\S' && $input_line !~ '^ *[!]' );

   my $comment;
   ($input_line,$comment) = &split_by_comment($input_line);

   if ($not_blank) {               # if not blank ...

      &find_new_scoping_unit($input_line); # <- Look for a new scoping unit ####

      &check_for_first_active_line($input_line); 

      ########################################### Found a NEW scope unit #######
      if ($newscopeunitfound) {
         if    ($newscopeunit eq 'module')         { &analyse_new_module_scope($input_line,"module"); }
         elsif ($newscopeunit eq 'virtual module') { &analyse_new_module_scope($input_line,"virtual module"); }
         elsif ($newscopeunit eq 'program')        { &analyse_new_module_scope($input_line,"program"); }
         elsif ($newscopeunit eq 'interface'
             && $parentscope  eq 'module')         { &analyse_new_module_interface_scope($input_line); }
         elsif ($newscopeunit eq 'type'  )         { &analyse_new_type_scope($input_line); }
         elsif ($newscopeunit eq 'array type'  )   { &analyse_new_type_scope($input_line); }
         elsif ($newscopeunit eq 'empty-end')      { &analyse_new_end_scope($input_line); }     # Inheritance in here
         elsif ($newscopeunit eq 'named-end')      { &analyse_new_end_scope($input_line); }
         elsif ($newscopeunit eq 'select' )        { $n_case_opt = 0 ; }
         elsif ($newscopeunit eq 'subroutine')     { &analyse_new_routine_scope($input_line); }
         elsif ($newscopeunit eq 'function')       { &analyse_new_routine_scope($input_line); }
      }

      ########################################### Within an EXISTING scope #####
      elsif ($scopeunit   eq 'program')        { &analyse_module_scope($input_line); }
      elsif ($scopeunit   eq 'module')         { &analyse_module_scope($input_line); }
      elsif ($scopeunit   eq 'interface' 
          && $parentscope eq 'module')         { &analyse_module_interface_scope($input_line); }
      elsif ($scopeunit   eq 'subroutine')     { &analyse_routine_scope($input_line); }
      elsif ($scopeunit   eq 'function')       { &analyse_routine_scope($input_line); }
      elsif ($scopeunit   eq 'interface')      { &analyse_interface_scope($input_line); }
      elsif ($scopeunit   eq 'type')           { &analyse_type_scope($input_line); }
      elsif ($scopeunit   eq 'array type')     { &analyse_type_scope($input_line); }

   } else { # Reset scopeunits for blank line or comment line
      $newscopeunit = undef;
      $newscopeunitfound = (defined $newscopeunit);
   }

   if (defined $comment) { $input_line .= $comment; }     # add comment back onto line.

                                                   # Store inherited stub
   if (&in_routine_scope) {
      if ( defined $current_rout_name && $routine{$current_rout_name}{inherited}
       && ! $routine{$current_rout_name}{being_inherited}) { 
         $inherit_string .= $input_inh . "\n";
         if ($input_inh =~ /^\s*\./) {
            &report_error("in inherited routine $current_rout_name, ".
                   "there appears to be active code :\n\n$input_line");
         }
      }
   }

}

################################################################################
# Open the fortran output file.
sub fortran_start {
  -f $fortranfile && unlink($fortranfile);
  open(FORTRANFILE,">".$fortranfile);
}

################################################################################
# End the fortran stuff, and close the fortran file.
sub fortran_end {
  close FORTRANFILE;
  &fortran_dump_interface;
  &fortran_dump_use; 
}

################################################################################
# Process the information into fortran.

sub process_foo_line {

   $fortran_out = $input_line;
   $skip_fortran_out = 0;

   $html_out = $input_line;
   $skip_html_out = 0;
   $html_do_indent = 0;

   $tidy_out = $input_line;
   $skip_tidy_out = 0;
   if (defined $current_rout_name &&
       defined $routine{$current_rout_name}{being_inherited} &&
               $routine{$current_rout_name}{being_inherited} == 1) { 
      $skip_tidy_out = 1; }

   $html_out = &html_change_special_chars($html_out);

   if ($input_line !~ m/^\s*$/o) {
     ########################################### Found a NEW scope unit #####
     if ($newscopeunitfound) {
       if    (&is_new_routine_scope)             { &do_new_routine_scope; }
       elsif (&is_new_module_interface_scope)    { &do_new_module_interface_scope; }
       elsif (&is_new_routine_interface_scope)   { &do_new_routine_interface_scope; }
       elsif ($newscopeunit eq 'module')         { &do_new_module_scope; }
       elsif ($newscopeunit eq 'virtual module') { &do_new_virtual_module_scope; }
       elsif ($newscopeunit eq 'program')        { &do_new_program_scope; }
       elsif ($newscopeunit eq 'contains')       { &do_new_contains_scope; }
       elsif ($newscopeunit eq 'type')           { &do_new_type_scope; }
       elsif ($newscopeunit eq 'array type')     { &do_new_type_scope; }
       elsif ($newscopeunit eq 'empty-end')      { &do_new_end_scope; }
       elsif ($newscopeunit eq 'named-end')      { &do_new_end_scope; }
       elsif ($newscopeunit eq 'do')             { &do_new_do_scope; }
       elsif ($newscopeunit eq 'parallel do')    { &do_new_parallel_do_scope; }
       elsif ($newscopeunit eq 'if')             { &do_new_if_scope; }
       elsif ($newscopeunit eq 'select')         { &do_new_select_scope; }
       elsif ($newscopeunit eq 'forall')         { &do_new_forall_scope; }
       elsif ($newscopeunit eq 'where')          { &do_new_where_scope; }
     }

     ########################################### Within an EXISTING scope #####
     elsif (&in_module_interface_scope)     { &do_module_interface_scope; }
     elsif (&in_routine_interface_scope)    { &do_routine_interface_scope; }
     #elsif ($scopeunit eq 'program')        { &do_program_scope; }
     elsif ($scopeunit eq 'module')         { &do_module_scope; }
     elsif ($scopeunit eq 'type')           { &do_type_scope; }
     elsif ($scopeunit eq 'array type')     { &do_type_scope; }
     elsif ($scopeunit eq '')               { &do_header_scope; }
     elsif (&in_routine_scope)              { &do_routine_scope; }
   }

   # The following is if we are in a routine body in some scope ...
   if (&scope_has_routine)                { &do_routine_body; }
   elsif (&scope_has_program)             { &do_program_scope; }

   # Print the processed line!
   if (  $do_fortran &&
       ! $module_is_virtual &&
       ! $skip_fortran_out)  { print FORTRANFILE $fortran_out; }

   # Print the processed line!
   if ($do_tidy && ! $skip_tidy_out)  { 
      $tidy_out = &tidy_fix_comment_indent($tidy_out);
      print TIDYFILE $tidy_out; 
   }
}

################################################################################
# Fix the comment indent in the foo files to two characters
sub tidy_fix_comment_indent {
   my $line = shift;
   $line =~ s/^   ! (?:\S)/   !  /;
   return $line;
}

################################################################################
# Return TRUE if the scope has a routine/function somewhere in the scope stack
sub scope_has_routine {
   my @has_routine = grep(/(subroutine)|(function)/,@scope);
   if ($#has_routine>=0) { return 1; }
   else                  { return undef; }
}

################################################################################
# Return TRUE if the scope has a program somewhere in the scope stack
sub scope_has_program {
   my @has_routine = grep(/program/,@scope);
   if ($#has_routine>=0) { return 1; }
   else                  { return undef; }
}

################################################################################
# Return TRUE if the scope has an interface  somewhere in the scope stack
sub scope_has_interface {
   my @has_interface = grep(/interface/,@scope);
   if ($#has_interface>=0) { return 1; }
   else                    { return undef; }
}

################################################################################
# Return TRUE if the scope is WITHIN a routine interface
sub is_new_routine_scope {
   if (defined $newscopeunit && (
       $newscopeunit eq 'subroutine' || $newscopeunit eq 'function'))
        { return 1; }
   else { return undef; }
}

################################################################################
# Return TRUE if the scope is WITHIN a routine interface
sub in_routine_scope {
   if (defined $scopeunit && (
       $scopeunit eq 'subroutine' || $scopeunit eq 'function'))
        { return 1; }
   else { return undef; }
}

################################################################################
# Return TRUE if the scope is a NEW routine interface
sub is_new_routine_interface_scope {
   if ($newscopeunit eq 'interface' 
   && ($parentscope  eq 'subroutine' || $parentscope eq 'function')) 
        { return 1; }
   else { return undef; }
}

################################################################################
# Return TRUE if the scope is WITHIN a routine interface
sub in_routine_interface_scope {
   if ($scopeunit   eq 'interface' 
   && ($parentscope eq 'subroutine' || $parentscope eq 'function')) 
        { return 1; }
   else { return undef; }
}

################################################################################
# Return TRUE if the scope is a NEW routine interface
sub is_new_module_interface_scope {
   if ($newscopeunit eq 'interface' && $parentscope eq 'module') 
        { return 1; }
   else { return undef; }
}

################################################################################
# Return TRUE if the scope is WITHIN a routine interface
sub in_module_interface_scope {
   if ($scopeunit eq 'interface' && $parentscope eq 'module') 
        { return 1; }
   else { return undef; }
}

################################################################################
#
# Look for a new scoping unit. 
#
# $scopeunit is the current scope unit AFTER this line. It may be reset after
# this routine.
#
# $oldscopeunit is the scope unit determined immediately BEFORE this routine is
# called i.e. BEFORE the current line.
#
# $parentscope is the enclosing scope of the current scope unit AFTER this line,
# if it exists, otherwise it is blank. Obviously $parentscope is the same as
# $oldscopeunit if a new non-end scopeunit is found, but it differs if an end
# scope is found.
#
# $newscope is the scope unit at the exit of this routine. If no new scope was
# found on this, it remains UNDEFINED. 
#
# $newscopeunitfound is set TRUE only if a new scoping unit was detected by this
# routine.
#
################################################################################

sub find_new_scoping_unit {

  my ($tmp,$scope);

  undef $newscopeunit;    

#print "-------------------------";
#print "    scope = $scopeunit";
#print "  @ scope = @scope";
#print "old scope = $oldscopeunit";
#print "par scope = $parentscope";

  # Do the tests based on the parent scope, to save on otherwise pointless
  # tests.  (e.q., can't have a module definition in a do loop).

  if ($scopeunit eq 'function' || $scopeunit eq 'subroutine' || $scopeunit eq 'program') {
    if ($_[0] =~ m'do'o && $_[0] =~ m'(?:^|:) *do *(?= [a-zA-Z]|$|[\#!;])'o) { # do
        $newscopeunit = 'do';
    } elsif ($_[0] =~ m'parallel do'o && $_[0] =~ m'(?:^|:) *parallel do *(?= [a-zA-Z]|$|[\#!;])'o) { # parallel do
        $newscopeunit = 'parallel do';
    } elsif ($_[0] =~ m'if'o && $_[0] =~ m'^ *if *[(][^;]*[)] *then(?=(?: *$)|(?: *[!;]))'o) { # if
        $newscopeunit = 'if';
    } elsif ($_[0] =~ m'interface'o && $_[0] =~ m'^ *interface *(?=[a-zA-Z]|$)'o) { # interface
        $newscopeunit = 'interface';
    } elsif ($_[0] =~ m'select'o && $_[0] =~ m'^ *select *[a-zA-Z]'o) { # select
        $newscopeunit = 'select';
    } elsif ($_[0] =~ m'forall'o && $_[0] =~ m'^ *forall *[(]'o && $_[0] !~ m'^ *forall *[(].*[)] *.*='o) { # forall
        $newscopeunit = 'forall';
    } elsif ($_[0] =~ m'where'o && $_[0] =~ m'^ *where *[(][^;]*[)] *(?=(?: *$)|(?: *[!;]))'o) { # where
        $newscopeunit = 'where';
    } elsif ($_[0] =~ m'type'o && $_[0] =~ m'^ *type *[a-zA-Z]'o) { # type
        $newscopeunit = 'type';
    } elsif ($_[0] =~ m'contains'o && $_[0] =~ m'^ *contains'o) { # contains
        $newscopeunit = 'contains';
    }
  } elsif ($scopeunit =~ 'module') {
    if ($_[0] =~ m'interface'o && $_[0] =~ m'^ *interface *(?=[a-zA-Z]|$)'o) { # interface
        $newscopeunit = 'interface';
    } elsif ($_[0] =~ m'contains'o && $_[0] =~ m'^ *contains'o) { # contains
        $newscopeunit = 'contains';
    } elsif ($_[0] =~ m'type'o && $_[0] =~ m'^ *type *[a-zA-Z]'o) { # type
        $newscopeunit = 'type';
    } elsif ($_[0] =~ m'type'o && $_[0] =~ m'^ *array type *[a-zA-Z]'o) { # type
        $newscopeunit = 'array type';
    }
  } elsif ($scopeunit eq 'interface') {
    if ($_[0] =~ m'type'o && $_[0] =~ m'^ *type *[a-zA-Z]'o) { # type
        $newscopeunit = 'type';
    } elsif ($#scope > 1) {
      if ($_[0] =~ '\s*result\s*[(](\w+)[)]' ) { # function
        $newscopeunit = 'function';
      } elsif ($_[0] =~ '\w') { # subroutine
        $newscopeunit = 'subroutine';
      }
    }
  } elsif ($scopeunit eq 'type') {
  } elsif ($scopeunit eq 'do' || $scopeunit eq 'parallel do' || $scopeunit eq 'if' || $scopeunit eq 'select') {
    if ($_[0] =~ m'do'o && $_[0] =~ m'(?:^|:) *do *(?= [a-zA-Z]|$|[\#!;])'o) { # do
        $newscopeunit = 'do';
    } elsif ($_[0] =~ m'parallel do'o && $_[0] =~ m'(?:^|:) *parallel do *(?= [a-zA-Z]|$|[\#!;])'o) { # parallel do
        $newscopeunit = 'parallel do';
    } elsif ($_[0] =~ m'if'o && $_[0] =~ m'^ *if *[(][^;]*[)] *then(?=(?: *$)|(?: *[!;]))'o) { # if
        $newscopeunit = 'if';
    } elsif ($_[0] =~ m'select'o && $_[0] =~ m'^ *select *[a-zA-Z]'o) { # select
        $newscopeunit = 'select';
    } elsif ($_[0] =~ m'forall'o && $_[0] =~ m'^ *forall *[(]'o && $_[0] !~ m'^ *forall *[(].*[)] *.*='o) { # forall
        $newscopeunit = 'forall';
    } elsif ($_[0] =~ m'where'o && $_[0] =~ m'^ *where *[(][^;]*[)] *(?=(?: *$)|(?: *[!;]))'o) { # where
        $newscopeunit = 'where';
    }
  } elsif ($scopeunit eq 'forall' || $scopeunit eq 'where') {
  } elsif ($scopeunit eq 'contains') {
    if ($_[0] =~ '\s*result\s*[(](\w+)[)]' ) { # function
      $newscopeunit = 'function';
    } elsif ($_[0] =~ '\w') { # subroutine
      $newscopeunit = 'subroutine';
    }
  } else { # must be without a parent scopeunit.
    if ($_[0] =~ m'program'o && $_[0] =~ m'^ *program *[a-zA-Z]'o) { # program
        $newscopeunit = 'program';
    } elsif ($_[0] =~ m'virtual *module'o && $_[0] =~ m'^ *virtual *module *[a-zA-Z]'o) { # virtual module
        $newscopeunit = 'virtual module';
    } elsif ($_[0] =~ m'module'o && $_[0] =~ m'^ *module *[a-zA-Z]'o) { # module
        $newscopeunit = 'module';
    }
  }

  # Test for end of scope.

  if ($_[0] =~ m'end'o) {
    if ($_[0] =~ m'^ *end *[a-z](?!.*[=(.])'o) { # named-end
      $newscopeunit = 'named-end';
    } elsif ($_[0] =~ m'^ *end *(?=!|$)'o) { #empty-end
      $newscopeunit = 'empty-end';
    }
  }

  $newscopeunitfound = (defined $newscopeunit);

  if (! defined $newscopeunit) { $newscopeunit = ''; }

  if ($newscopeunitfound) {
    # add $scope to the scope stack.
    if ($newscopeunit !~ '-end$')  { &push_scope; }
    else                           { &pop_scope;  } 
  } else {
    $oldscopeunit = $scopeunit;
  }

# print "found scope line------> $_[0]";
# print "new scope = $newscopeunit";
# print "    scope = $scopeunit";
# print "  @ scope = @scope";
# print "old scope = $oldscopeunit";
# print "par scope = $parentscope";
}

################################################################################
# This line is within the scope of a module.
sub analyse_module_scope {

    # Analyse any module variable declaration lines
    if ($_[0] =~ ' *:: *[A-Z][\w{,}()]' ) {
       &analyse_variable_declaration($_[0],\%global_var_info);
       # Assign global variable types to local
       %local_var_info = %global_var_info;
       # Keep used module
       $used_modules{$current_type_name} = 1;
    }
}

################################################################################
# The line is within the scope of an interface within a module.
sub analyse_module_interface_scope {
}

################################################################################
# The line is within the scope of a subroutine or function.
sub analyse_routine_scope {
  my($X);

  # Check if/forall/where syntax.
  if ($_[0] =~ m'^\s*if\s*'o) { # if
    $_[0] =~ m'^\s*if\s*[(].*[)]\s*\S+'o || &report_error("if syntax not recognised.");
  } elsif ($_[0] =~ m'^\s*forall\s*'o) { # forall
    $_[0] =~ m'^\s*forall\s*[(].*[)]'o || &report_error("forall syntax not recognised.");
  } elsif ($_[0] =~ m'^\s*where\s*'o) { # where
    $_[0] =~ m'^\s*where\s*[(].*[)]'o || &report_error("where syntax not recognised.");
  }


  if (defined $routine{$current_rout_name}{template} &&
              $routine{$current_rout_name}{template} == 1) { 
     return; }

  # Analyse any variable declaration lines
  if ($_[0] =~ m' *:: *[A-Z][\w{,}()]'o ) {
     $X = $_[0];
     $X = &convert_inherited_type_arg_macros($X);
     &analyse_variable_declaration($X,\%local_var_info);
     # Keep used module
     if (defined $current_type_name) { $used_modules{$current_type_name} = 1; }
  }

  if ($do_tidy) { &store_ensure_statements; }

}

################################################################################
# Store ENSURE statements which appear before the first active line and output
# the later at the first active line
sub store_ensure_statements {

    if ($input_line =~ /ENSURE/ ||
        $input_line =~ /DIE_IF/ ) {
        if ($pass==1 && # Only store on the first pass
            $routine{$current_rout_name}{first_active_line} == 0 &&
          ! $routine{$current_rout_name}{in_routine_body} ) {
            if ($routine{$current_rout_name}{found_local_var_decl} &&
              ! $do_tidy ) {
               &report_error("in routine $current_rout_name, put ENSURE statements ".
                   "before local variable declarations:\n\n$input_line");
            }
            my $line = $input_line;
            $line =~ s/^\s*/   /;
            $routine{$current_rout_name}{ensure_statements} .= $line . "\n";
            $skip_tidy_out = 1;
        }
    }
}

################################################################################
# Determine whether this is the first active line of a routine, i.e. the first
# line which is a true code line, and not a variable declaration. 

sub check_for_first_active_line {

   my $name = $current_rout_name;

   return if (! defined $name);
   return if (! defined $routine{$name});
   return if (! &scope_has_routine);
   return if ($scopeunit    eq 'interface'); # Skip interface bodies
   return if ($oldscopeunit eq 'interface'); 

   # Now we are in a routine scope

      $routine{$name}{first_local_var_decl} = undef;
   
      if (defined $routine{$name}{first_active_line} &&
                  $routine{$name}{first_active_line} == 1) {
             $routine{$name}{first_active_line} = undef; # Stop looking
      }
      elsif (
          defined $routine{$name}{first_active_line} && 
                  $routine{$name}{first_active_line} == 0 && (   # This is set to 0 if in a routine
          $_[0] =~ '^\s*[a-zA-Z.]' || 
          $_[0] =~ '^\s*#' ) && # WARNING: active line if preprocessor directive
          $_[0] !~ '::'      && 
          $_[0] !~ ' use '   &&
          $_[0] !~ 'ENSURE'  &&
          $_[0] !~ 'DIE_IF'  ) {
             $routine{$name}{first_active_line} = 1;  
             $routine{$name}{in_routine_body} = 1;  
      }

}


################################################################################
# The line is within the scope of an interface in a subroutine or function.
sub analyse_interface_scope {
  # Analyse the routine name
  &analyse_rout_name($_[0]);
  $routine{$current_rout_name}{real_name} = $current_rout_name;
}

################################################################################
# The line is within the scope of a type.
sub analyse_type_scope {

  if ($scopeunit eq 'array type') {
     &report_error("components are not allowed inside an array type definition.");
  }

  # Analyse a module type declaration body
  if ($_[0] =~ '::' ) {
     &analyse_variable_declaration($_[0],$module_type{$module_type_name});
     # Keep used module
     $used_modules{$current_type_name} = 1;
  }

}

############################################################################
# split the line into it's non-comment and comment parts, if applicable.

sub split_by_comment {
  my ($x,$y,$i,$left,$right);
  $x = $_[0];
  if ($x !~ '!') { # no comment
    return ($x,'');
  } else {
    $i = 0;
    while ($i < length $x) {
      $y = substr $x,$i,1;
      if ($y eq '!') {
        $left = substr $x,0,$i;
        $right = substr $x,$i;
        if (&outside_of_string($left)) {
          return ($left,$right);
        }
      }
      $i++;
    }
    return ($x,'');
  }
}

############################################################################
# Return whether we are outside of a quoted string.
sub outside_of_string {
  my(@tmp,$i,$y,$in_single,$in_double);
    $i = 0;
    $in_single = 0;
    $in_double = 0;
    while ($i < length $_[0]) {
      $y = substr $_[0],$i,1;
      if ($y eq '\'' && ! $in_double) { $in_single = ! $in_single;}
      if ($y eq '"' && ! $in_single) { $in_double = ! $in_double;}
      $i++;
    }
    return (! ($in_single || $in_double));
}

############################################################################
# Return whether we are outside of a HTML quote <blah> ....</blah>. 
sub outside_of_HTML_quote {
  my(@tmp,$i,$y,$in_inner,$in_outer);
    $i = 0;
    $in_inner = 0;
    $in_outer = 0;
    while ($i < length $_[0]) {
      $y = substr $_[0],$i,1;
#print "y,out,in=",$y,$in_outer,$in_inner;
      if    ($y eq '<' && ! $in_outer) { $in_outer = 1;}
      elsif ($y eq '>' &&   $in_outer && ! $in_inner ) { $in_inner = 1;}
      elsif ($y eq '>' &&   $in_outer) { $in_outer = 0; $in_inner = 0 }
      $i++;
    }
    return (! $in_outer);
}

############################################################################
#                          Conversion to HTML

############################################################################
sub html_start {
  -f $htmlshortfile && unlink($htmlshortfile);
  -f $htmllongfile && unlink($htmllongfile);
  open(HTMLSHORTFILE,">".$htmlshortfile) or die "$htmlshortfile: $!.\nStopped";
  open(HTMLLONGFILE,">".$htmllongfile) or die "$htmllongfile: $!.\nStopped";
  $HTMLSHORTHANDLE = *HTMLSHORTFILE;
  $HTMLLONGHANDLE = *HTMLLONGFILE;
  &html_put_header;
  &html_print("\n",1);
  &html_print("\n",1);
  &html_print("<H2>Synopsis:</H2>",1);
}

############################################################################
sub html_put_header {
# This routine outputs the HTML header.  The first argument to this routine is
# the output file handle, as a string.
  &html_print("<HTML>",1)
  &html_print("<HEAD>",1)
  &html_print("  <META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; CHARSET=iso-8859-1\">",1)
  &html_print("  <META NAME=\"robots\" CONTENT=\"noindex, nofollow\">",1)
  &html_print("  <LINK REL=\"STYLESHEET\" TYPE=\"text/css\" HREF=\"../tonto.css\">",1)
  &html_print("  <TITLE>Documentation for $module_full_name</TITLE>",1)
  &html_print("</HEAD>",1)
  &html_print("<BODY BGCOLOR=\"#FFFFFF\" CLASS=\"FOODOC\"><BASEFONT SIZE=3>",1)
  &html_print("<DIV CLASS=\"TITLE\"><H1>Documentation for $module_full_name</H1></DIV>",1)
  &html_print('<BR><IMG SRC="../hr.png" HEIGHT=10 WIDTH=100%><BR>',1)
}

############################################################################
#
sub html_end {
  print HTMLLONGFILE "\n<BR><IMG SRC=\"../hr.png\" HEIGHT=10 WIDTH=100%><BR>";
  print HTMLLONGFILE "</BODY>";
  print HTMLLONGFILE "</HTML>";
  close HTMLLONGFILE;

  print HTMLSHORTFILE "\n<BR><IMG SRC=\"../hr.png\" HEIGHT=10 WIDTH=100%><BR>";
  print HTMLSHORTFILE "</BODY>";
  print HTMLSHORTFILE "</HTML>";
  close HTMLSHORTFILE;
}

############################################################################
# Expects the global hash %used_modules to contain the unique list of 
# modules that are used (as keys).
sub html_put_use_list {
  my ($mod,$tmp);
  if (keys(%used_modules) > 0) {
    &html_print("\n",1);
    &html_print("\n",1);
    &html_print("<BR><H2>Used Modules:</H2>",1);
    &html_print("<DIV CLASS=\"INDENT\">");
    foreach $mod (sort keys %used_modules) {
      if ($mod eq '')                { next; }
      if ($mod eq 'unknown')         { next; }
      if ($mod eq $module_full_name) { next; }
      $tmp = lc($mod);
      if ($mod =~ /virtual/) {
         $mod =~ /(\w+)/;
         &html_print("   <A CLASS=\"TYPE\" NAME=\"$1\">$1</A> (virtual)");
      } else {
         &html_print("   <A CLASS=\"TYPE\" HREF=\"${tmp}_short.html\">$mod</A>");
      }
    }
    &html_print("</DIV>");
  }
}

############################################################################
# This subroutine outputs the HTML for a subroutine/function declaration.
sub html_do_new_routine_scope {

  my ($routname,$arg,$result,$attr,$real_name,$name,$tmp);

  #                    space routine   arguments            function result                attributes
  $html_out =~ m/^ (\s*)  (\w+) (?:(\([\s\w,]+\)))? \s* (?:result\s*\(([\s\w]+)\))? (?:\s*:::\s*(.*?))?\s*$/x;
  if (defined $2) { $routname = $2 }                                   else { $routname = '' }
  if (defined $3) { 
         $arg = $3;
         my @tmp = split(/\b/,$arg);
         my $word;
         foreach $word (@tmp) {
            if ($word =~ '^\w') { 
               $word = "<A CLASS=\"ARG\">" . $word . '</A>'; }
         }
         $arg = join('',@tmp);
  } else { $arg = '' }
  if (defined $4) { $result = ' result (<A CLASS="ARG">'.$4.'</A>)' } else { $result = '' }
  if (defined $5) { $attr = ' ::: <A CLASS="ATTR">'.$5.'</A>' } else { $attr = '' }

  # Link get_from to the place where it's inherited from, if applicable.
  if ($attr =~ m'get_from'o && $attr =~ m'get_from[(]([^),]*)([),])'o) {
     if (defined $tonto_type_info{$1}) {
        $tmp = lc $1;
        $attr = $PREMATCH . 
                "get_from</A>(<A CLASS=\"TYPE\" HREF=\"${tmp}_short.html#$routname\">$1<\/A>" . 
                "<A CLASS=\"ATTR\">$2" . $POSTMATCH;
     } else {
        $attr = $PREMATCH . 
                "get_from</A>(<A CLASS=\"TYPE\" HREF=\"#$1\">$1<\/A>" . 
                "<A CLASS=\"ATTR\">$2" . $POSTMATCH;
     }
  }
  $real_name = $routine{$current_rout_name}{short_name};

  # Change attributelinks
  my ($old,$new);
  $tmp = $attr;
  while ($attr =~ m'define_type\(\s*([\w{,}.]+)\s*,\s*([\w{,}.]+)\s*\)'g) {
     if (defined $tonto_type_info{$1}) { $old = "<A CLASS=\"TYPE\" HREF=\"${1}_short.html\">$1<\/A>"; }
     elsif (&is_used_module($1))       { $old = "<A CLASS=\"TYPE\" HREF=\"#$1\">$1<\/A>"; }
     else                              { $old = "<A CLASS=\"TYPE\">$1<\/A>"; }
     if (defined $tonto_type_info{$2}) { $new = "<A CLASS=\"TYPE\" HREF=\"${2}_short.html\">$2<\/A>"; }
     elsif (&is_used_module($2))       { $new = "<A CLASS=\"TYPE\" HREF=\"#$2\">$2<\/A>"; }
     else                              { $new = "<A CLASS=\"TYPE\">$2<\/A>"; }
     $tmp = $PREMATCH .  'define_type</A>(' . $old . ',' . $new . 
            ")<A CLASS=\"ATTR\">" . $POSTMATCH;
  }
  $attr = $tmp;

  if ($attr =~ /\bdefine\b/ && $attr =~ /[.]/) { $attr = &dots_to_html($attr); }

  my ($html_short,$html_long);
  if (! &scope_has_interface) {
     $html_short = "<A CLASS=\"ROUTINE\" NAME=\"${real_name}\" HREF=\"${foofile_head_name}.html#${real_name}\">";
     $html_long  = "<A CLASS=\"ROUTINE\" NAME=\"${real_name}\" HREF=\"${foofile_head_name}_short.html#${real_name}\">";
  } else { # must be an interface for routine argument
     $html_out = "<A CLASS=\"ARG\">";
     $html_short = $html_out;
     $html_long  = $html_out;
  }
  $html_short .= "${routname}</A>${arg}${result}${attr}";
  $html_long  .= "${routname}</A>${arg}${result}${attr}";
  if (! defined $module{$module_name}{found_procedure}) {
     $module{$module_name}{found_procedure} = 1;
  } else {
     if (! &scope_has_interface) { 
        print $HTMLSHORTHANDLE "\n<BR>";
        print $HTMLLONGHANDLE  "\n<BR>\n<BR>\n<BR>";
     }
  }
# &html_print($html_out);
  print $HTMLSHORTHANDLE $html_short.'<BR>';
  print $HTMLLONGHANDLE  $html_long.'<BR>';
  if (! &scope_has_interface) { &html_print("<DIV CLASS=\"INDENT\">"); }   # with <br>
  else                        { &html_print("<DIV CLASS=\"INDENT\">",1); } # no <br>
}

############################################################################
# Return TRUE if the module $name is in the used module list.
sub is_used_module {
   my ($name) = @_;
   if (grep(/^$name\b/,keys %used_modules)) { return 1;}
   else                                     { return 0;}
}

############################################################################
sub html_put_self_type_components {

  if (defined $module{$module_name}{found_module_var} ||
      defined $module{$module_name}{found_module_interface} ) {
        &html_print("</DIV>",1);
    }

  &html_print("\n",1);
  &html_print("\n",1);
  &html_print("<BR><H2>Type Components:</H2>",1);
  &html_print("<DIV CLASS=\"INDENT\">");

  if ($module_is_intrinsic) {
     &html_print("$module_name is a built-in intrinsic SCALAR type");
     &html_print("</DIV>",1);
     return;
  }

  if ($module_is_array &&
     &is_intrinsic_scalar_type_name($type_arg[1])) {
     &html_print("$module_name is a built-in ARRAY of intrinsic scalar type");
     &html_print("</DIV>",1);
     return;
  }

  open(TYPESFILE,$typesfile);

  my $found = 0;
  my $n = 0;
  my $comment = undef;
  my $X;

  while (chop ($X = <TYPESFILE>) ) {

      if ($X =~ "type *$module_name") { $found = 1; next; }

      if ($X =~ "^ *end" && $found)   { last; }

      next if (! $found);

      if ($X =~ '(.*)::(.*)') {         # A variable declaration
         my $left = $1;
         my $right = $2;

         $n++;

         #Process left side first.  Make the variables link targets.
         my @tmp = split('\b',$left);
         my $word;
         foreach $word (@tmp) {
            if ($word =~ '\w') { 
               $word = "<A CLASS=\"TYPEFIELD\" NAME=\"$word\">" . $word . '</A>'; }
         }
         $left = join('',@tmp);

         #Now do right side.  Link to any types we know of.
         $right =~ /([A-Z][\w{,}.]*[A-Z0-9}])/;
         $right = "$PREMATCH<A CLASS=\"TYPE\" HREF=\"" . (lc $1) . '_short.html">' . $1 . '</A>' . $POSTMATCH;

         #Merge them back together.
         $X = $left . '::' . $right;
         
         if ($n > 1) { &html_print("\n"); }
         &html_print($X);
         &html_print("<DIV CLASS=\"INDENT\">");
         $comment = undef;
      }

      elsif ($X =~ /^(\s*)!(.*)/) {     # A type comment.
         if (! defined $comment) {
            $comment = 1;
            $X =~ s/^(\s*)!(.*)/... $2/;
            $X = "<A CLASS=\"COMMENT\">$X";
         } else {
            $X =~ s/^(\s*)!(.*)/$2/;
         }
         &html_print($X,1);
      }

      elsif ($X =~ /^ *$/ && $comment) {    # The end of a comment
         $comment = undef;
         &html_print("</A>",1); # end comment
         &html_print("<BR>",1);
         &html_print("</DIV>",1);
      }

  }

  &html_print("</DIV>",1); 

  close TYPESFILE;

}

################################################################################
# This routine outputs HTML $out to the appropriate file. A break is used unless
# $no_br isd set to 1. Output goes to both short and long unless $long_only is
# set to 1.
sub html_print {

  my ($out,$no_br,$long_only) = @_;

  # Collapse multiple spaces down to one, seeing browsers do this anyway.
  $out =~ s/\s{2,}/ /og;

  if (defined $no_br && $no_br==1) { }
  else             { $out .= '<BR>'; }

  if (defined $long_only && $long_only) {
     print $HTMLLONGHANDLE $out;
  } else {
     print $HTMLSHORTHANDLE $out;
     print $HTMLLONGHANDLE $out;
  }
}


################################################################################
#                          Conversion to Fortran
################################################################################


################################################################################
# Dump the interface file

sub fortran_dump_interface {
  my ($cnt,$pub,$pvt,$rout);

  -f "$fortranintfile" && unlink("$fortranintfile");

  return if $is_program;
  return if ($module_full_name eq '');

  open(INTFILE,">"."$fortranintfile");

  if ($module_full_name ne 'TYPES') {
    print INTFILE "   private";   # All specific interfaces are made private
  } else {
    print INTFILE "   public";    # ... unless this is the TYPES module.
  }
  print INTFILE "";

  foreach $rout (sort keys %overload_count) {
      next if (defined $routine{$rout}{inlined_by_foo});
      next if ($do_usd && ! defined $usd{$rout});
      $cnt = $overload_count{$rout}-1;
      $pvt = $routine{$rout}{generic_access};
      if ($do_generic) {
               print INTFILE "   $pvt    ${rout}_";
         if ($cnt==0) {
            $pub = $routine{$rout}{specific_access};
            if ($pub eq "public") {
               print INTFILE "   $pub    ${rout}";
            }
         } else {
            for (my $i = 0; $i <= $cnt; $i++) {
               $pub = $routine{$rout.'_'.$i}{specific_access};
               next if ($pub eq "private");
               print INTFILE "   $pub    ${rout}_$i";
            }
         }
               print INTFILE "   interface ${rout}_";
         if ($cnt==0) {
               print INTFILE "      module procedure ${rout}";
         } else {
            for (my $i = 0; $i <= $cnt; $i++) {
               print INTFILE "      module procedure ${rout}_$i";
            }
         }
               print INTFILE "   end interface";
      } else { # -------- AVOID GENERIC INTERFACES
               print INTFILE "   $pvt    ${module_fort_name}_${rout}";
         if ($cnt==0) {
               # Generic is same as specific for first name
         } else {
            for (my $i = 0; $i <= $cnt; $i++) {
               $pub = $routine{$rout.'_'.$i}{specific_access};
               next if ($pub eq "private");
               print INTFILE "   $pub    ${module_fort_name}_${rout}_$i";
            }
         }
         if ($cnt==0) {
         } else {
               print INTFILE "   interface ${module_fort_name}_${rout}";
            for (my $i = 0; $i <= $cnt; $i++) {
               print INTFILE "      module procedure ${module_fort_name}_${rout}_$i";
            }
               print INTFILE "   end interface";
         }
      }
               print INTFILE "";
  }
  close INTFILE;
}


################################################################################
# Dump the USE file

sub fortran_dump_use {
  my ($first,$ftime,$fpara,$rout);

  -f $fortranusefile && unlink($fortranusefile);

  return if ($module_full_name eq '');

  open(USEFILE,">".$fortranusefile);

  # Everyone must use TYPES and SYSTEM.
  if ($module_full_name ne 'TYPES')  {
    print USEFILE "   use TYPES_MODULE";
    if ($module_full_name ne 'SYSTEM')  {
      if ($do_system eq 1) {
      print USEFILE "\n   use SYSTEM_MODULE";
      }
    }
  }

  my ($mod,$fort_mod,$fort_typ,$fort_fun);

  # Loop over the TONTO modules $mod to which the called routines belong
  foreach $mod (sort keys %called_routines) { 

      print USEFILE " ";

      if ($mod eq 'SYSTEM' || $mod eq 'TYPES') {next;}
      $first = 0;
      $ftime = 0;
      $fpara = 0;

      # Loop over all routines $rout called which belong to module $mod
      # The name $rout may be overloaded, of course. 
      foreach $rout (sort keys %{$called_routines{$mod}}) {
         # This is the mangled fortran module name of the called routine
         $fort_mod = $called_routines{$mod}{$rout}{fortran_mod_name};
         $fort_typ = $called_routines{$mod}{$rout}{fortran_type_name};
         $fort_fun = $called_routines{$mod}{$rout}{function_call};
         if ($mod eq "TEXTFILE" && $first==0 && $mod ne $module_full_name) {
            print USEFILE "   use TEXTFILE_MODULE, only: stdin";
            print USEFILE "   use TEXTFILE_MODULE, only: stdout";
            print USEFILE "   use TEXTFILE_MODULE, only: stderr";
            $first = 1;
         }

         if ($mod eq "TIME" && $ftime==0 && $mod ne $module_full_name) {
            print USEFILE "   use TIME_MODULE, only: std_time";
            $ftime = 1;
         }

         if ($mod ne "unknown" && $mod ne $module_full_name) {
            if ($do_generic) {
               if (defined $fort_fun and $fort_fun==1) {
                  print USEFILE "   use ${fort_mod}_MODULE, only: ${rout}";
               } else {
                  print USEFILE "   use ${fort_mod}_MODULE, only: ${rout}_";
               }
            } else {
                  print USEFILE "   use ${fort_mod}_MODULE, only: ${fort_mod}_${rout}";
            }
         } elsif ($mod eq "unknown") {
            if ($do_generic) {
               if (defined $fort_fun and $fort_fun==1) {
                  print USEFILE "!  use ${fort_mod}_MODULE, only: ${rout}";
               } else {
                  print USEFILE "!  use ${fort_mod}_MODULE, only: ${rout}_";
               }
            } else {
                  print USEFILE "!  use ${fort_mod}_MODULE, only: ?_${rout}";
            }
         }
      }
  }
  close USEFILE;
}


################################################################################
# Change the start of the routine by adding START_TIMER, STACK, and ENSURE
# macros. Also add a comment if the routine is inherited for clarity.

sub fortran_add_stack_macro {

  my $name = $current_rout_name;

  my $pre_out = "";

  if ($routine{$name}{first_active_line}) {
     if ($do_stack eq 1 && ! defined $routine{$name}{pure}) {
        $pre_out  = "   STACK(\"$module_full_name:${routine{$name}{real_name}}\")";
     }
     if ($do_timer eq 1) {
        if ($pre_out ne '') { $pre_out .= "\n" }
        $pre_out .= "   START_TIMER(\"$module_full_name:${routine{$name}{real_name}}\")";
     }
     if (defined $routine{$name}{fortran_ensure_statements}) {
        if ($pre_out ne '') { $pre_out .= "\n" }
        $pre_out .= $routine{$name}{fortran_ensure_statements};
        $routine{$name}{fortran_ensure_statements} = undef;
     }
     if (defined $routine{$name}{being_inherited}) {
        if ($pre_out ne '') { $pre_out .= "\n" }
        $pre_out .= "   ! The following code is inherited from " .  
                    $routine{$name}{parent_module};
     }
     if ($pre_out ne '') {
        $fortran_out = $pre_out . "\n" . $fortran_out;
     }
  }

}


################################################################################
# Change the return statement by adding STOP_TIMER, UNSTACK or CHECK macros.

sub fortran_process_return {

  my $name = $current_rout_name;

  # found a "return" #######################
  if ($fortran_out =~ '.return') {

    my $unstk = "UNSTACK(\"$module_full_name:${routine{$name}{real_name}}\")";
    my $check = "CHECK(\"$module_full_name:${routine{$name}{real_name}}\")";
    if ($do_timer eq 1 && $do_stack eq 1) {
      if ($fortran_out =~ '[)] *return *(?:!|$)' ) {
        if    (defined $routine{$name}{pure})  { $fortran_out =~ s/[)] *return */) then; STOP_TIMER; return; end if/o; }
        elsif (defined $routine{$name}{leaky}) { $fortran_out =~ s/[)] *return */) then; STOP_TIMER; $unstk; return; end if/o; }
        else                                   { $fortran_out =~ s/[)] *return */) then; STOP_TIMER; $check; return; end if/o; }
      }
      elsif ($fortran_out =~ '(?:^|;) *return *' ) {
        if    (defined $routine{$name}{pure})  { $fortran_out =~ s/return/STOP_TIMER; return/o; }
        elsif (defined $routine{$name}{leaky}) { $fortran_out =~ s/return/STOP_TIMER; $unstk; return/o; }
        else                                   { $fortran_out =~ s/return/STOP_TIMER; $check; return/o; }
      }
    } elsif ($do_stack eq 1) {
      if ($fortran_out =~ '[)] *return *(?:!|$)' ) {
        if    (defined $routine{$name}{pure})  {  }
        elsif (defined $routine{$name}{leaky}) { $fortran_out =~ s/[)] *return */) then; $unstk; return; end if/o; }
        else                                   { $fortran_out =~ s/[)] *return */) then; $check; return; end if/o; }
      }
      elsif ($fortran_out =~ '(?:^|;) *return *' ) {
        if    (defined $routine{$name}{pure})  {  }
        elsif (defined $routine{$name}{leaky}) { $fortran_out =~ s/return/$unstk; return/o; }
        else                                   { $fortran_out =~ s/return/$check; return/o; }
      }
    } elsif ($do_timer eq 1) {
      if ($fortran_out =~ '[)] *return *(?:!|$)' ) {
        if    (defined $routine{$name}{pure})  { $fortran_out =~ s/[)] *return */) then; STOP_TIMER; return; end if/o; }
        elsif (defined $routine{$name}{leaky}) { $fortran_out =~ s/[)] *return */) then; STOP_TIMER; return; end if/o; }
        else                                   { $fortran_out =~ s/[)] *return */) then; STOP_TIMER; return; end if/o; }
      }
      elsif ($fortran_out =~ '(?:^|;) *return *' ) {
        if    (defined $routine{$name}{pure})  { $fortran_out =~ s/return/STOP_TIMER; return/o; }
        elsif (defined $routine{$name}{leaky}) { $fortran_out =~ s/return/STOP_TIMER; return/o; }
        else                                   { $fortran_out =~ s/return/STOP_TIMER; return/o; }
      }
    }
  }
}


################################################################################
# Change case statements with the UNKNWON macro appropriately.

sub fortran_process_case_statements {
  my($tmp,$indent,$i,$unknown_arg,$name);

  # Store all case string arguments
  if ($fortran_out =~ /case/) {
    $tmp = $fortran_out;
    if ($tmp =~  'case *\( *("[^"]*")') {
      $tmp =~ s/case *\( *//o;
      while ( $tmp =~ s/^ *,? *("[^"]*")//o ) {
         $n_case_opt++;
         $case{$n_case_opt} = $1;
      }
    }
  }

  # Dump the case string arguments as a checking construct
  # This can really bloat the code!

  if ($do_unknown eq 1) {
     if ($fortran_out =~ 'UNKNOWN\(.*\)') {
       $fortran_out =~ s/UNKNOWN\((.*)\)/allocate\(tonto\%known_keywords\($n_case_opt\)\)/o;
       $unknown_arg = $1;
       ($indent = $fortran_out) =~ '^(\s*)';
       $indent = $1;
       $fortran_out = $fortran_out . "\n";
       for ($i=1 ; $i <= $n_case_opt; $i++) {
          $fortran_out .= $indent . "tonto\%known_keywords($i) = " . $case{$i} . "\n";
       }
       $name = $current_rout_name;
       if ($do_generic) {
       $fortran_out .= $indent . 
           "call unknown_(tonto,$unknown_arg,\"$module_full_name:${routine{$name}{real_name}}\")\n";
       } else {
       $fortran_out .= $indent . 
           "call SYSTEM_unknown(tonto,$unknown_arg,\"$module_full_name:${routine{$name}{real_name}}\")\n";
       }
       $fortran_out .= $indent . "deallocate(tonto\%known_keywords)";
     }
  }
}


################################################################################
# Change ENSURE/WARN/DIE to have the routine name in them, or eliminate
# entirely if we are in a pure routine.

sub fortran_process_error_management {
  my($error_string,$name);

  $name = $current_rout_name;
  if (defined $routine{$name}{pure}) {
    $fortran_out =~ s/ENSURE.*$//o;
    $fortran_out =~ s/VERIFY.*$//o;
    $fortran_out =~ s/DIE_IF.*$//o;
    $fortran_out =~ s/WARN_IF.*$//o;
    $fortran_out =~ s/DIE\(".*$//o;
    $fortran_out =~ s/WARN\(".*$//o;
  } else {
    $error_string = "$module_full_name:${routine{$name}{real_name}} ... ";
    if ($fortran_out =~ 'ENSURE') { $fortran_out =~ s/(^.*), *"([^"]*)"/$1,"$error_string$2"/m; }
    if ($fortran_out =~ 'VERIFY') { $fortran_out =~ s/(^.*), *"([^"]*)"/$1,"$error_string$2"/m; }
    if ($fortran_out =~ 'DIE_IF') { $fortran_out =~ s/(^.*), *"([^"]*)"/$1,"$error_string$2"/m; }
    if ($fortran_out =~ 'WARN_IF') { $fortran_out =~ s/(^.*), *"([^"]*)"/$1,"$error_string$2"/m; }
    if ($fortran_out =~ 'DIE\("') { $fortran_out =~ s/DIE\("/DIE\("$error_string/m; }
    if ($fortran_out =~ 'WARN\("') { $fortran_out =~ s/WARN\("/WARN\("$error_string/m; }
  }

# # Split the ENSURE & DIE_IF off the STACK; this also bloats the code.
# if ($fortran_out =~ '^ *STACK') {
#   $fortran_out =~  s/\)( *)ENSURE\(/\)\n$1ENSURE\(/;
#   $fortran_out =~  s/\)( *)ENSURE[\$]\(/\)\n$1ENSURE[\$]\(/;
#   $fortran_out =~  s/\)( *)DIE_IF\(/\)\n$1DIE_IF\(/;
# }
}
################################################################################
# Convert inherited type and type arg macros. Also convert any explicitly
# defined type substitutions.

sub convert_inherited_type_arg_macros {

   my $fortran_out = $_[0];

   # Inherited type/type arguments

   my $name = $current_rout_name;

   if ( ! $not_blank)                        { return ($fortran_out) }

#print "--------------------------------------------";
#print "line    =",$_;
#print "in body =",$routine{$name}{in_routine_body};
#print "active  =",$routine{$name}{first_active_line};
#print "inh     =",$routine{$name}{inherited};
#print "being   =",$routine{$name}{being_inherited};

   if ($routine{$name}{inherited}) {

      my ($i,$j,$narg,$arg,$newarg);

      if ($n_define_type>0) {
      
# print "YUP, line= $input_line";
# print "YUP, line= $fortran_out";
         for ($i=1; $i<=$n_define_type ; $i++) {
            $arg    = $old_define_type[$i];
            $newarg = $new_define_type[$i];
            $arg =~ s/\(/\\(/g; $arg =~ s/\)/\\)/g;
            $arg =~ s/\{/\\{/g; $arg =~ s/\}/\\}/g;
            $arg =~ s/\./\\./g; $arg =~ s/\?/\\?/g;
            $arg =~ s/\*/\\*/g; $arg =~ s/\+/\\+/g;
            $fortran_out =~ s/${arg}/${newarg}/g;
# print "arg = $arg";
# print "newarg = $newarg";
# print "YUP, line= $fortran_out";
            my @old = @{$old_expand_type[$i]};
            my @new = @{$new_expand_type[$i]};
            $narg = ($#old<$#new?$#old:$#new);
            if ($narg>0) {
# print "INNER narg = $narg";
               for ($j=1; $j<=$narg ; $j++) {
                  $arg    = $old[$j];
                  $newarg = $new[$j];
                  $arg =~ s/\(/\\(/g; $arg =~ s/\)/\\)/g;
                  $arg =~ s/\{/\\{/g; $arg =~ s/\}/\\}/g;
                  $arg =~ s/\./\\./g; $arg =~ s/\?/\\?/g;
                  $arg =~ s/\*/\\*/g; $arg =~ s/\+/\\+/g;
# print "arg = $arg";
# print "newarg = $newarg";
                  $fortran_out =~ s/${arg}/${newarg}/g;
               }
            }
         }
# print "YUP, fort= $fortran_out";
      }
 
      if (! $routine{$name}{in_routine_body}) {
   
         # Convert the parent module type to the inherted module type
         my $type_name = $routine{$name}{parent_module};
         $fortran_out =~ s/\b${type_name}\b/${module_full_name}/;
      
         # Convert the parent module type args to the inherted module type args
         if ($n_inherited_type_args>0 && $n_type_args>0) {
      
            $narg = ($n_type_args<$n_inherited_type_args?
                     $n_type_args:$n_inherited_type_args);
      
            for ($i=1; $i<=$narg ; $i++) {
               $arg    = $inherited_type_arg[$i];
               $newarg = $type_arg[$i];
               $fortran_out =~ s/\b${arg}/${newarg}/;
            }
         }
         # Remove len= specifiers in everything which is not an array of STR
         if (! ($module_is_array && $type_arg[1] eq 'STR')) {
            $fortran_out =~ s/[(]len=.*,/[(]/;
            $fortran_out =~ s/[(]len=.*[)]//;
         }
      }
   }

   return ($fortran_out);

}


################################################################################
# Convert square bracket array-of-arrays notation

sub fortran_convert_array_of_arrays {

  my $fortran_out = $_[0];

  $fortran_out =~ s/\]\[([^]]*)\]/].element($1)/go; 
  $fortran_out =~ s/\)\[([^]]*)\]/).element($1)/go; 
  $fortran_out =~ s/(\w)\[([^]]*)\]/$1.element($2)/go; 

  return ($fortran_out);

}


################################################################################
# Add DEFAULT initialisation.

sub fortran_add_default_initialisation {
  #  if ($inp =~ ':: +INT *$') {                   $inp .= " DEFAULT(0)"}
  #  if ($inp =~ ':: +REAL *$') {                   $inp .= " DEFAULT(ZERO)"}
  #  if ($inp =~ ':: +STR *$') {                   $inp .= " DEFAULT(\" \")"}
  #  if ($inp =~ ':: +REALVEC[(][^)]*[)] *$') {      $inp .= " DEFAULT(ZERO)"}
  #  if ($inp =~ ':: +CPXVEC[(][^)]*[)] *$') {      $inp .= " DEFAULT(ZERO)"}
  #  if ($inp =~ ':: +INTVEC[(][^)]*[)] *$') {       $inp .= " DEFAULT(0)"}
  #  if ($inp =~ ':: +REALMAT[3-7][(][^)]*[)] *$') { $inp .= " DEFAULT(ZERO)"}
  #  if ($inp =~ ':: +CPXMAT[3-7][(][^)]*[)] *$') { $inp .= " DEFAULT(ZERO)"}
  #  if ($inp =~ ':: +INTMAT[3-7][(][^)]*[)] *$') {  $inp .= " DEFAULT(0)"}
     if ($fortran_out =~ ':: +.*[*] *$') { $fortran_out .= " DEFAULT_NULL" }
}


################################################################################
# The line is within the scope of an interface in a subroutine or function.
sub do_routine_interface_scope {
   if ($do_fortran && $not_blank) { &fortran_do_routine_interface_scope; }
}


################################################################################
# The line is within the scope of an interface in a subroutine or function.

sub fortran_do_routine_interface_scope {
  my($name,$attr,$args,$pre);
  $name = $current_rout_name;

  $pre = $routine{$name}{indent};

  $attr = '';
  if    (defined $routine{$name}{always_elemental}) { $attr = 'ALWAYS_ELEMENTAL '; }
  elsif (defined $routine{$name}{elemental})        { $attr = 'ELEMENTAL '; }
  elsif (defined $routine{$name}{always_pure})      { $attr = 'ALWAYS_PURE '; }
  elsif (defined $routine{$name}{pure})             { $attr = 'PURE '; }
  if    (defined $routine{$name}{recursive})        { $attr .= 'recursive '; }

  $args = '';
  if (defined $routine{$name}{arg_string}) { $args = $routine{$name}{arg_string}; }

  if (defined $routine{$name}{function}) {
    $fortran_out = "${pre}${attr}function ${name}${args}";
  } else {
    $fortran_out = "${pre}${attr}subroutine ${name}${args}";
  }
}


################################################################################
# Process new 'module' scope.
sub do_new_module_scope {
   if ($do_fortran) { &fortran_do_new_module_scope; }
}

################################################################################
# Process new 'module' scope to Fortran.
sub fortran_do_new_module_scope {
  $fortran_out  = "module ${module_fort_name}_MODULE";
  $fortran_out .= "\n\n" . 
                  "#  include \"${fortranusefile}\"";
}

################################################################################
# Process new 'module' scope.
sub do_new_virtual_module_scope {
   if ($do_fortran) { &fortran_do_new_virtual_module_scope; }
}

################################################################################
sub fortran_do_new_virtual_module_scope {
  $fortran_out =~ s/^[ ]*virtual *module ([A-Z]\w*)/virtual module $1_MODULE ! This is a virtual module/;
  $fortran_out .= "\n\n" . "!  include \"${fortranusefile}\"";
}


################################################################################
# Analayse the new scoping unit, the beginning of a module.

sub analyse_new_module_scope {

  my ($line,$virtual) = @_;

  if ($virtual eq 'virtual module') { $module_is_virtual = 1; }
  else                              { $module_is_virtual = 0; }

  my $run;
  if ($virtual eq 'program') { $is_program = 1; $run = 'run_'; }
  else                       { $is_program = 0; $run = ''; }

  # Get the long and short module names ...
  $line =~ m/^[ ]*$virtual $run([A-Z][\w{,}.]*)/o;
  $module_full_name = $1;                          # This includes any dotted part at end

  if (! defined $module_full_name) {
    my $tmp = '';
    if ($line =~ m/^[ ]*$virtual $run([A-Z][\w{,}.]*)/io) {
      my $x = $1;
      $module_full_name = uc($x);
      $tmp = "Perhaps you meant \"$run$module_full_name\"?\n";
    }
    &report_error("unrecognised type in \"$virtual\" name:\n\n$line\n\n$tmp");
  }
  
  my %info = &analyse_type_name($module_full_name,0);

  $module_name       = $info{type_name};           # Chops the dotted part, but includes curlies ...
  $module_fort_type  = $info{fortran_type_name};   # Fortran type name -- without submodule part
  $module_fort_name  = $info{fortran_mod_name};    # Fortran module name for USE statements
  $module_self_decl  = $info{fortran_self_decl};   # Fortran module name for :: self declarations
  $module_head_name  = $info{type_head_name};      # Fortran module head name for array modules
  $n_type_args       = $info{n_type_args};         # The number of type arguments
  @type_arg          = @{$info{type_arg}};         # The type arguments - WITHOUT arguments of arguments.
  $module_is_intrinsic = $info{is_intrinsic_type}; # True if the module is intrinsic
  $module_is_array     = $info{is_array_type};     # True if the module is array

  # Now get all the type arguments -- including arguments of arguments -- in
  # depth first order of nested curly brackets.
  @type_arg = &get_all_type_arguments(\@type_arg);
  $n_type_args = $#type_arg;

  if (! defined($tonto_type_info{$module_name}) &&
     $module_name ne 'TYPES' &&
     $virtual ne 'virtual module') {
     &report_error("module type \"$module_name\" was not defined in \"$typesfile\".");
  }

  # Check head name is same as the lower case module_name ...
  if (lc($run.$module_full_name) ne $foofile_head_name) {
     &report_error("module name \"$run$module_full_name\" does not match" .
     " file-head name \"$foofile_head_name\".");
  }

  # Assign the self type. It is of the type $module_name WITHOUT subtype part
  if (defined $tonto_type_info{$module_name}) { # not defined for virtual modules
     %{$global_var_info{self}} = %{$tonto_type_info{$module_name}};
     %{$local_var_info{self}} = %{$tonto_type_info{$module_name}};
  }

  # Reset module name, if is a program. 
  # A program should not have a dotted part.
  $module_name = $run.$module_name;
  $module_full_name = $run.$module_full_name;

}

################################################################################
sub do_new_program_scope {
   if ($do_fortran) { &fortran_do_new_program_scope; }
}

################################################################################
sub fortran_do_new_program_scope {
  $fortran_out  = "program run_${module_fort_name}";
  $fortran_out .= "\n\n" . 
                  "#  include \"${fortranusefile}\"";

  if ($do_routine_calls && $pass==2) {
     $current_rout_name = lc($module_full_name);
     print RCFILE "$current_rout_name";
  }
}

################################################################################
sub do_new_contains_scope {
   if ($do_html ) { &html_do_new_contains_scope; }
}

############################################################################
sub html_do_new_contains_scope {

  &html_put_self_type_components; # <===========

  &html_print("\n",1);
  &html_print("\n",1);
  &html_print("<BR><H2>Method Components:</H2>",1);
  &html_print("<DIV CLASS=\"INDENT\">");
}

################################################################################
# The line is a new scoping unit, which is an interface.
sub analyse_new_module_interface_scope {

  # Change the interface declaration
  $_[0] =~ m/^\s*interface\s*([a-z]\w*)/o;
  $name = $1;
  if ($#scope<=2) { 
     $current_rout_name = $name; 
   # print "set current_rout_name to $current_rout_name";
  }
}

################################################################################
# The line is a new scoping unit, which is a type.
sub analyse_new_type_scope {

  if ($parentscope ne 'module') {
    &report_error("type definition may only appear within a module scope.");
  } 

  my $type_name = $_[0];

  $type_name =~ '\s+type +([A-Z][\w{,}.]*)';
  $type_name = $1;
  &analyse_type_name($type_name);
  $module_type_name = $type_name;
  # Create module_type hash
  $module_type{$module_type_name}{'--exists--'} = 1; 
  # Assign global variable types to local
  undef %local_var_info;
  %local_var_info = %global_var_info
}

################################################################################
# Replace the tonto type notation. The tonto type information is already
# generated by &analyse_types_file.
sub do_new_type_scope {
   if ($do_fortran) { &fortran_do_new_type_scope; }
}


################################################################################
# Replace the tonto type notation with an acceptable fortran version. The tonto
# type information is already generated by &analyse_types_file.
sub fortran_do_new_type_scope {

   if    ($scopeunit eq 'array type') {
      $fortran_out = "";        # Array types are for the preprocessor only
   }
   elsif ($fortran_out =~ m'(^\s*type\s+)([A-Z][\w{,}.()-*=+/:]*[*]?)(.*)$'o) {
      my $left      = $1;
      my $type_name = $2;
      my $right     = $3;
      if ($tonto_type_info{$type_name}{sub_type_name} ne '') {
         &report_error("sub-type name not allowed for type \"$type_name\".");
      }
      my $fortran_type = $tonto_type_info{$type_name}{fortran_type_name};
      $fortran_out = $left . $fortran_type . "_TYPE" . $right;
   }

}

################################################################################
# The line is a labelled or unlabelled end keyword.
sub analyse_new_end_scope {
  my($i,$getfile,$found,$name);

  $name = $current_rout_name;

  if ( defined $oldscopeunit &&
      ($oldscopeunit eq 'subroutine' || $oldscopeunit eq 'function') 
      && $#scope <= 3) {

      # End a module routine. Need ns<=3 to eliminate interface routines

      ##################################################################
      # Inheritance ####################################################
      ##################################################################

      if (  $do_inherit &&
            $routine{$name}{inherited} && 
          ! $routine{$name}{being_inherited}) {

          # We have reached the end of a stub routine. Now we look for the
          # corresponding stub in the $getfile. The stub is stored in
          # $inherit_string.  We set the 'being_inherited' switch.

          $routine{$name}{being_inherited} = 1;
          $routine{$name}{first_active_line} = 0; 
          $routine{$name}{in_routine_body} = undef; 
                                      # Set the getfile name
          $getfile = lc($routine{$name}{parent_module}) . ".foo";
          if ($foofile_directory ne "") {
            $getfile = File::Spec->catpath($foofile_volume,$foofile_directory,$getfile);
          }
          open(GETFILE, $getfile) || 
            &report_error("can't find \"$getfile\" to inherit routine ...\n\n$inherit_string.");
            &start_foofile(*GETFILE,$getfile); # and get the procedure interfaces.
                                      # Remove spaces which don't affect the interface
          my @inherit = split('\n',$inherit_string);

        # $inherit[0] =~ s/\s*$//o;
        # $inherit[0] =~ s/\s*:::.*//o;
          if ($routine{$name}{parent_routine}) {
             $inherit[0] =~ s/$routine{$name}{short_name}/$routine{$name}{parent_routine}/;
          }
          my $i = 0;
          my $found = 0;
          my $inh;

          for ($i=0; $i <= $#inherit; $i++) {
            $inh = $inherit[$i];
            $inh =~ s/\s*$//o;           # Remove spaces
            $inh =~ s/\s*:::.*//o;       # Remove special foo attributes
            $inh = &convert_inherited_type_arg_macros($inh);
            $inherit[$i] = $inh;
          }
          $inh = $inherit[0];
                                      # Start looking for the interface
          while (<GETFILE>) {        
             $filelinenum{$foohandle}++;
             chomp;
             $_  =~ s/\s*$//o;
             $_  =~ s/\s*:::.*//o;
             $_ = &convert_inherited_type_arg_macros($_);
             if    ($_ ne $inh)     { $i=0; $inh = $inherit[$i]; }
             elsif ($i <  @inherit) { $i++; $inh = $inherit[$i]; }
             if    ($i == @inherit) { $found = 1; last }
          }
          if ($found==0) {
            &report_error("can't find inherit routine ...\n\n$inherit_string");
          }

          $inherit_string = "";       # FOUND! Reset the inherit string
                                      # Undo end detection
          $newscopeunit = $oldscopeunit;
          &push_scope;
                                      # Process next line as if end was never there ...
          $_ = <GETFILE>;
          $filelinenum{$foohandle}++;
          &analyse_foo_line;

      } else {

          # This is really the end of a routine. BUt we may need to swap files
          # back in case this was an inherited routine ...

          if ($do_inherit &&
              $routine{$name}{being_inherited}) {

             close GETFILE;            # close parent file
             &end_foofile;
             undef $routine{$name}{inherited};
             undef $routine{$name}{being_inherited};
             undef $routine{$name}{in_routine_body};
             $inherit_string = "";
          }

          # Delete the local type table --- here, or in end_new_end
          # Do this for all "real" end-of-routines, even inherited.

          if ($#scope < 3) {
             undef %local_var_info;
          }

      }
  }
  
  elsif (defined $scopeunit && $scopeunit eq 'type') {

     delete $module_type{$module_type_name}{'--exists--'};
   # %{$module_type{$type_name . "_"}} = %{$module_type{$type_name}};
     %tonto_type = (%tonto_type,%module_type); # Add onto tonto type
     delete $module_type{$module_type_name};

  }

}

################################################################################
# Add a scoping unit to the scope stack.  Also set $newscopeunitfound,
# $newscopeunit and $oldscopeunit.
sub push_scope {
    $oldscopeunit = $scopeunit; 
    $scopeunit = $newscopeunit;
    push @scope, $scopeunit;
    &set_parent_scope;
}

################################################################################
# Remove one element from the scope stack, and set $oldscopeunit to the last
# element on the stack. This is only called for -end scopes.
sub pop_scope {
    $oldscopeunit = $scopeunit; 
    pop @scope;
    $scopeunit = $scope[$#scope];
    if ($#scope < -1) {
      &report_error("unmatched end.");
    }
    &set_parent_scope;

    # The following is needed because an interface in a routine may
    # reset the current_rout_name, which is needed in a lot of places.

    if ($oldscopeunit =~ '(subroutine)|(function)' && $scopeunit eq 'interface' ) {
       $current_rout_name = pop @rout_name_stack;
       $routine{$current_rout_name}{template} = 0;  
       $current_rout_name = $rout_name_stack[$#rout_name_stack];
    }

    # Pop the contains scope once more since it really ends a module

    if ($oldscopeunit eq 'contains' 
     && $scopeunit    eq 'module' )         { &pop_scope; };

}

################################################################################
# Set the parent scope.

sub set_parent_scope {

    if   ($#scope>=1) { $parentscope = $scope[$#scope-1]; } 
    else              { $parentscope = ''; }

}

################################################################################
# Process the end of new scoping unit into Fortran.
sub do_new_end_scope {
   if ($do_fortran) { &fortran_do_new_end_scope; }
   if ($do_html)    { &html_do_new_end_scope; }
   if ($do_tidy)    { &tidy_do_new_end_scope; }
}

################################################################################
# Replace intitial indent for .vim folding.
sub tidy_do_new_end_scope {
   if ($oldscopeunit eq 'subroutine' || $oldscopeunit eq 'function') { 
   my $indent = $routine{$current_rout_name}{indent};
   $tidy_out =~ s/^$indent/   /;
   }
}

################################################################################
# Process the end of new scoping unit into Fortran.
sub html_do_new_end_scope {

  if   ($oldscopeunit eq 'subroutine' || $oldscopeunit eq 'function') { 
   # if (! defined $routine{$current_rout_name}{found_var_decl} &&
   #       defined $routine{$current_rout_name}{found_comment_line}) {
   #     &html_print('</A>'); # end comment if there, and a break
   # }
     if (! defined $routine{$current_rout_name}{found_var_decl} &&
         ! defined $routine{$current_rout_name}{found_comment_line}) {
         &html_print('');
         &html_print('');
     }
     if ($scopeunit ne 'interface') { &html_print("<BR>",1); }      # Space if not interface
     &html_print("</DIV>",1);                                       # end routine indent
     if ($scopeunit eq 'interface') { &html_print($html_out); }     # Print end interface
     else                           { &html_print($html_out,0,1); } # always 'end interface' to LONG

  } elsif ($oldscopeunit eq 'interface' &&
           $scopeunit    eq 'module') {            # module interface
     &html_print("</DIV>",1);
   # &html_print($html_out,0,0);
  } elsif ($oldscopeunit eq 'interface') {         # routine interface
     &html_print("</DIV>",1);
     &html_print($html_out,0,0);
     $skip_html_out = 1;
  } elsif ($oldscopeunit eq 'select') {            # select case
     $html_out = "</DIV></DIV>".$html_out;         # Two lots for case
  } else {
     $html_out = "</DIV>".$html_out;               # Delay print, in routine body
  }

}

################################################################################
# Process the end of new scoping unit into Fortran.
sub fortran_do_new_end_scope {

  my($i,$getfile,$found,$name,$pre_out);
  $name = $current_rout_name;

#print "-----------------------> end scope";
#print "     scope  = $scopeunit";
#print " old scope  = $oldscopeunit";
#print " # scope    = $#scope";
#print " name       = ",$routine{$name}{pure};
#print " pure       = ",$routine{$name}{pure};
#print " fortran_out= ",$fortran_out;
#print "-----------------------> end scope";

  if   (($oldscopeunit eq 'subroutine' || $oldscopeunit eq 'function') 
      && ! &scope_has_interface) { # need to eliminate interface routines
     if ($routine{$current_rout_name}{inlined_by_foo}) {
        $skip_fortran_out = 1; return;
     }
     if ($routine{$current_rout_name}{template}) {
        $skip_fortran_out = 1; return;
     }
     my $unstk = "UNSTACK(\"$module_full_name:${routine{$name}{real_name}}\")";
     my $check = "CHECK(\"$module_full_name:${routine{$name}{real_name}}\")";
     if ($do_timer eq 1 && $do_stack eq 1) {
        if    (defined $routine{$name}{pure})  { 
           # $fortran_out =~ s/end */end $oldscopeunit/; 
           $fortran_out =~ s/(\s*)end */$1STOP_TIMER\n$1end $oldscopeunit/; 
        }
        elsif (defined $routine{$name}{leaky}) { 
           $fortran_out =~ s/(\s*)end */$1STOP_TIMER\n$1$unstk\n$1end $oldscopeunit/; 
        }
        else                                     { 
           $fortran_out =~ s/(\s*)end */$1STOP_TIMER\n$1$check\n$1end $oldscopeunit/; 
        }
     } elsif ($do_stack eq 1) {
        if    (defined $routine{$name}{pure})  { 
           $fortran_out =~ s/end */end $oldscopeunit/; 
        }
        elsif (defined $routine{$name}{leaky}) { 
           $fortran_out =~ s/(\s*)end */$1$unstk\n$1end $oldscopeunit/; 
        }
        else                                     { 
           $fortran_out =~ s/(\s*)end */$1$check\n$1end $oldscopeunit/; 
        }
     } elsif ($do_timer eq 1) {
           $fortran_out =~ s/(\s*)end */$1STOP_TIMER\n$1end $oldscopeunit/; 
     } else {
           $fortran_out =~ s/(\s*)end */$1end $oldscopeunit/; 
     }
     $pre_out = "";
     if ( $do_stack eq 1 &&
          ! defined $routine{$name}{pure} &&
            defined $routine{$current_rout_name}{first_active_line} &&
                    $routine{$current_rout_name}{first_active_line} == 0) {
        $pre_out  = "   STACK(\"$module_full_name:${routine{$name}{real_name}}\")\n";
     }
     $fortran_out = $pre_out . $fortran_out;
  } 

  elsif ($oldscopeunit eq 'array type') {
        $fortran_out = ""; #Do not output anything for array types.
  }

  elsif ($oldscopeunit eq 'interface') {
   # print "current_rout_name = $current_rout_name";
   # print "used              = $usd{$current_rout_name}";
   # print "scope             = $#scope";
   # if (defined $#scope) { print "scope defined"; }
   # print "do_usd            = $do_usd";
   # if (defined $do_usd) { print "usd defined"; }
   # print "short_name        = $usd{$routine{$current_rout_name}{short_name}}";
     if    ($#scope<1 && $do_usd && ! defined $usd{$current_rout_name}) {
   #    print "HERE";
        $skip_fortran_out = 1; return; # MOdule interface
     }
     elsif ($#scope>=2 && $do_usd && ! defined $usd{$routine{$current_rout_name}{short_name}}) {
   #    print "HERE2";
        $skip_fortran_out = 1; return; # Routine interface
     } else {
        $fortran_out =~ s/end\s*/end $oldscopeunit/;
     }
  }

  elsif ($oldscopeunit eq 'parallel do') {
        $fortran_out =~ s/end\s*/end do/;
        $fortran_out =~ /^(\s*)/; 
# print "mod = $module_full_name";
        $fortran_out .= "\n" . $1 . "UNLOCK_PARALLEL_DO(\"" .
                        $module_full_name . ":" .
                        $routine{$current_rout_name}{real_name} . "\")";
  }

  elsif ($fortran_out =~ /end\s*(?:$|!)/) { # not named end
        $fortran_out =~ s/end\s*/end $oldscopeunit/;
  }

}

################################################################################
# The line is the start of a subroutine or function.
sub analyse_new_routine_scope {

  # Expecting a subroutine/function line
  &analyse_rout_name($_[0]);

  # Assign global variable types to local
  # Don't do this for routines that are within interfaces.
  if ($#scope < 3) {
    undef %local_var_info;
    %local_var_info = %global_var_info;
    if (! $module_is_virtual) {
    %{$local_var_info{self}} = %{$tonto_type_info{$module_name}};
    }
  }
}

################################################################################
# Process a new do scope.
sub do_new_do_scope {
   if ($do_html)    { $html_do_indent = 1; }
}

################################################################################
# Process a new do scope.
sub do_new_parallel_do_scope {
   if ($do_fortran) { &fortran_do_new_parallel_do_scope; }
   if ($do_html)    { $html_do_indent = 1; }
}

################################################################################
# Process new 'module' scope to Fortran.
sub fortran_do_new_parallel_do_scope {
  if ($fortran_out =~ /^(\s*)parallel\s do                    # do part
                        (?:\s+(\w+)\s*=\s*(\S+)\s*,\s*(\S+))? # variable and limits
                        (?:\s*,\s*(\S+))?                     # stride part
                        (\s*$|\s*!.*$)/x) {
      if (defined $2 && defined $5) {
         $fortran_out = "$1do $2 = PARALLEL_DO_START($3,$5),$4,PARALLEL_DO_STRIDE($5)$6";
      }
      elsif (defined $2) {
         $fortran_out = "$1do $2 = PARALLEL_DO_START($3,1),$4,PARALLEL_DO_STRIDE(1)$6";
      }
# print "mod = $module_full_name";
      $fortran_out .= "\n" . $1 . "LOCK_PARALLEL_DO(\"" .
                      $module_full_name . ":" .
                      $routine{$current_rout_name}{real_name} ."\")";
  }
}

################################################################################
# Process a new if scope.
sub do_new_if_scope {
   if ($do_html)    { $html_do_indent = 1; } 
}

################################################################################
# Process a new if scope.
sub do_new_select_scope {
   if ($do_html)    { $html_do_indent = 2; }
}

################################################################################
# Process a new if scope.
sub do_new_forall_scope {
   if ($do_html)    { $html_do_indent = 1; }
}

################################################################################
# Process a new if scope.
sub do_new_where_scope {
   if ($do_html)    { $html_do_indent = 1; }
}

################################################################################
# Process a new do scope.
sub html_add_indent {
   $html_out = $html_out . "<DIV CLASS=\"INDENT\">";
}

################################################################################
# Process new 'interface'.
sub do_new_module_interface_scope {
   if ($do_fortran) { &fortran_do_new_module_interface_scope; }
   if ($do_html)    { &html_do_new_module_interface_scope; }
}

############################################################################
# Write a header for the generic interfaces
sub html_do_new_module_interface_scope {
  if (! defined $module{$module_name}{found_module_interface}) {
    if (defined $module{$module_name}{found_module_var}) {
        &html_print("</DIV>",1);
    }
    &html_print("\n",1);
    &html_print("\n",1);
    &html_print("<BR><H2>Explicit interfaces:</H2>",1);
    &html_print("<DIV CLASS=\"INDENT\">");
    $module{$module_name}{found_module_interface} = 1;
  }
  if ($html_out =~ /\binterface\b/io) {
    $html_out =~ /^\s*interface\s*(\w+)/;
    &html_print("\n<BR><A CLASS=\"ROUTINE\" NAME=\"$1\">$1</A>:");
    &html_print("<DIV CLASS=\"INDENT\">");
  }
}

################################################################################
# Process new 'interface'.
sub do_new_routine_interface_scope {
   if ($do_html) { &html_do_new_routine_interface_scope; }
}

################################################################################
# The line is within the scope of an interface in a subroutine or function.

sub html_do_new_routine_interface_scope {

   if (! defined $routine{$current_rout_name}{found_var_decl}) {

      if (defined $routine{$current_rout_name}{found_comment_line}) {
         &html_print('</A>'); # end comment if there, and a break
      }
      # the interface is a routine variable
      $routine{$current_rout_name}{found_var_decl} = 1; 
      &html_print('');  
   }
   &html_print($html_out);  # print the interface statement
   &html_print("<DIV CLASS=\"INDENT\">",1);
}

################################################################################
# Process new 'interface' into fortran.
sub fortran_do_new_module_interface_scope {

  my ($name);

  # Change the interface declaration
  $fortran_out =~ m/^\s*interface\s*([a-z]\w*)/o;

# $current_rout_name = $1;

  if ($do_usd && ! defined $usd{$current_rout_name}) {
      $skip_fortran_out = 1; return;
  }

  if ($do_generic) {
     $fortran_out = "   public    $1_\n   interface $1_";
  } else {
     $fortran_out = "   public    ${module_fort_type}_$1\n   interface ${module_fort_type}_$1";
  }
  if ($do_routine_calls && $pass==2) {
     print RCFILE $1;
  }
}

################################################################################
# The line is within the scope of an interface within a module.
sub do_module_interface_scope {
   if ($do_fortran && $not_blank) { &fortran_do_module_interface_scope; }
   if ($do_html && $not_blank) { &html_do_module_interface_scope; }
}

################################################################################
# The line is within the scope of an interface within a module.
sub html_do_module_interface_scope {

  my @tmp = split('\b',$html_out);
  my $rout;
  foreach $rout (@tmp) {
     next if ($rout !~ /\w+/);
     $rout = "<A CLASS=\"ROUTINE\" HREF=\"${foofile_head_name}_short.html#$rout\">$rout</A>"; 
  }
  $html_out = join('',@tmp);
  &html_print($html_out);

}

################################################################################
# The line is within the scope of an interface within a module.
sub fortran_do_module_interface_scope {

   if ($do_usd && ! defined $usd{$current_rout_name}) {
      $skip_fortran_out = 1; return;
   }

   # Get the indent
   $fortran_out =~ '([a-zA-Z]\w*)';
   my $pre  = $PREMATCH;
 
   # Set the module prepended part
   my ($mod);
   if (!$do_generic) { $mod = "${module_fort_type}_"; } 
   else              { $mod = "";                     }
 
   # Modify the module procedure part. All specific names are used for
   # overloaded procedures.
   my $new_out = '';
   my $n = 0;
   my $i;
   while ($fortran_out =~ /([a-zA-Z]\w*)/g) {
      $name = $1;
      $n++;
      if ( $n > 1 ) { $new_out .= "\n"; }
      if (defined $first_overload_count{$name} &&
                  $first_overload_count{$name} > 1 ) {
         my $i;
         for ($i=0; $i<$first_overload_count{$name}; $i++) {
            if ( $i > 0 ) { $new_out .= "\n"; }
            $new_out .= "${pre}module procedure ${mod}${name}_${i}";
         }
      } else {
            $new_out .= "${pre}module procedure ${mod}${name}";
      }
      if ($do_routine_calls && $pass==2) {
          my $call = "$module_full_name:$name";
          print RCFILE "   $call";
      }
   }
   $fortran_out = $new_out;
}

################################################################################
# The line is before any scope i.e. at the comment header.
sub do_header_scope {
   if ($do_html) { &html_do_header_scope; }
}

################################################################################
# The line is before any scope i.e. at the comment header.
sub html_do_header_scope {

   $skip_html_out = 1;          # Always skip unless the following applies ...
   if (! $html_synopsis_found && $html_out =~ "^! *$module_full_name") { 
      $html_synopsis_found = 1; # First line just found
      $html_out =~ s/^!\s*//; 
      &html_print($html_out,1);
   } elsif ($html_synopsis_found && $html_out =~ /This library is free software/) { 
      $html_out = '<A HREF="../GNU_license.html">License conditions for this software</A>';
      &html_print($html_out);
      &html_print('');
      $html_GNU_found = 1;      # Last line just found
   } elsif ($html_synopsis_found && ! $html_GNU_found) { 
      $html_out =~ s/^!\s*//;   # Between first and last line
      if ($html_out =~ /^ *$/) {
         &html_print('');
         &html_print('');
      } elsif ($html_out =~ /^\s*Copyright/) {;
         &html_print($html_out);
      } else {
         &html_print($html_out,1);
      }
   }

   if ($html_out =~ '\$Id:') { 
      $html_out =~ s/^\s*!\s*\$\s*(.*)\s*\$/$1/;
      $html_out = "<H2>Version Information</H2>\n" . $html_out; 
      &html_print($html_out);
   }

}

################################################################################
# The line is within the scope of a subroutine or function.

sub do_routine_scope {
   if ($do_fortran) { &fortran_do_routine_scope; }
   if ($do_html)    { &html_do_routine_scope; }
}

################################################################################
# The line is within the scope of a subroutine or function but NOT a routine
# body. The routine body stuff is done in another part, this just dies the
# declaration part at the head of the routine.

sub html_do_routine_scope {

   return if (!defined $current_rout_name);
   return if (!defined $routine{$current_rout_name});

   if (! $routine{$current_rout_name}{in_routine_body} ) {

      # This is to see if to print to $html_out LONG only ...

      my $long = 0; 
      if ($routine{$current_rout_name}{found_local_var_decl}) { $long = 1; }

      # This is for indenting continuation lines.

      if ($routine{$current_rout_name}{found_continuation} &&
           $html_out !~ /[&] *(!|$)/) {     # Continuation end found
         $routine{$current_rout_name}{found_end_continuation} = 1;
      } else {
         $routine{$current_rout_name}{found_end_continuation} = undef;
      }

      if ($html_out =~ /[&] *(!|$)/) {     # Continuation line found
         if (! defined $routine{$current_rout_name}{found_continuation}) {
            $routine{$current_rout_name}{found_continuation} = 1;
            $routine{$current_rout_name}{found_first_continuation} = 1;
         } else {
            $routine{$current_rout_name}{found_first_continuation} = undef;
         }
      } else {
         $routine{$current_rout_name}{found_continuation} = undef;
         $routine{$current_rout_name}{found_first_continuation} = undef;
      }

      # This is a comment header ....

      if (! defined $routine{$current_rout_name}{found_var_decl} &&
          ! defined $routine{$current_rout_name}{found_ensure} &&
          $html_out =~ s/^ *!//) {         

         $html_out = &dots_to_html($html_out,1);
         $html_out = &html_replace_routine_args($html_out,1);
         if (! defined $routine{$current_rout_name}{found_comment_line} ) {
            $routine{$current_rout_name}{found_comment_line} = 1;
            $html_out = "<A CLASS=\"COMMENT\">... $html_out"; # A routine comment
         }
         &html_print($html_out,1);

      # This is a comment but NOT header ....

      } elsif ($html_out =~ /^ *!/) {     

            $html_out = "<A CLASS=\"COMMENT\">$html_out</A>"; 
            &html_print($html_out,0,$long);

      # This is a variable declaration ....

      } elsif ($html_out =~ '(.*)::(.*)') { 

         my $left = $1;
         my $right = $2;

         #Do right side.  Link to any types we know of.
         $right = &convert_inherited_type_arg_macros($right);
         if ($left !~ '^ *self') {
            $right =~ /([A-Z][\w{,}.]*[A-Z0-9}])/;
            $right = $PREMATCH . '<A CLASS="TYPE" HREF="' . (lc $1) . '_short.html">' . $1 . 
                     '</A>' .  $POSTMATCH;
            $right = &dots_to_html($right);
         }

         #Process left side.  Make the variables link targets.
         if (! $routine{$current_rout_name}{found_local_var_decl}) {
#print "A=====> $left";
            $left = &html_replace_routine_args($left);
#print "B=====> $left";
         }

         #Merge them back together.
         $html_out = $left . '::' . $right;

         if (! defined $routine{$current_rout_name}{found_var_decl}) {
            if (! defined $routine{$current_rout_name}{found_ensure} &&
                  defined $routine{$current_rout_name}{found_comment_line}) {
               &html_print('</A>'); # end comment if there, and a break
            }
            if (! &scope_has_interface && (
                ! defined $routine{$current_rout_name}{found_ensure} ||
                $routine{$current_rout_name}{first_local_var_decl}) ) {
               &html_print('',0,$long);   # put a break on the first set of vars/ENSURE
            }
            $routine{$current_rout_name}{found_var_decl} = 1;
         }
         elsif ($routine{$current_rout_name}{first_local_var_decl}) {
            &html_print('',0,1); # put a break on the first set of local vars -- LONG only
         }

         &html_print($html_out,0,$long); # <===========

         if ($routine{$current_rout_name}{found_first_continuation}) {
            &html_print("<DIV CLASS=\"INDENT\">",1,$long); 
         } elsif ($routine{$current_rout_name}{found_end_continuation}) {
            &html_print("</DIV>",1,$long); 
         }

      # This is an ENSURE .....

      } elsif ($html_out =~ '^ *ENSURE' || $html_out =~ '^ *DIE_IF') { 

         # ENSURE statements always come before local variables.
         if (defined $routine{$current_rout_name}{found_comment_line} &&
           ! defined $routine{$current_rout_name}{found_var_decl} &&
           ! defined $routine{$current_rout_name}{found_ensure} ) {
            &html_print('</A>'); # end comment if there, and a break
            &html_print('');     # put a break on the first set of vars/ENSURE
         }
         $routine{$current_rout_name}{found_ensure} = 1;
         #  &html_print('');        # put break of first ensure

         $html_out = &convert_inherited_type_arg_macros($html_out);
         $html_out = &dots_to_html($html_out);
         $html_out =~ s'ENSURE'<A CLASS="ENSURE">ENSURE</A>';
         $html_out =~ s'DIE_IF'<A CLASS="ENSURE">DIE_IF</A>';
         $html_out = &html_replace_routine_args($html_out);
         &html_print($html_out);

      # Don't know what it is ... probably a continuation line ...

      } else {

         &html_print($html_out,0,$long);

         if ($routine{$current_rout_name}{found_first_continuation}) {
            &html_print("<DIV CLASS=\"INDENT\">",1,$long); 
         } elsif ($routine{$current_rout_name}{found_end_continuation}) {
            &html_print("</DIV>",1,$long); 
         }

      }
   }
}


################################################################################
# Replace the routine arguments in "html_out".

sub html_replace_routine_args {
   
   my ($html_out,$in_comment) = @_;

   my @tmp = split('\b',$html_out);
   my ($i,$word);
   for ($i=0; $i<=$#tmp; $i++ ) {
      $word=$tmp[$i];
#print "html = $html_out";
#print "word = $word";
      if (&routine_has_arg($word)) { 
#print "pre  =",( join('',@tmp[0..($i-1)]) );
#print "outside string? ",&outside_of_string( join('',@tmp[0..($i-1)]) );
#print "outside HTML?   ",&outside_of_HTML_quote( join('',@tmp[0..($i-1)]) );
         if ($in_comment) {
            $word = "</A><A CLASS=\"ARG\">" . $word . '</A><A CLASS="COMMENT">'; 
            $tmp[$i] = $word;
         } elsif (
            &outside_of_string( join('',@tmp[0..($i-1)]) ) &&
            &outside_of_HTML_quote( join('',@tmp[0..($i-1)]) ) ) {
            $word = "<A CLASS=\"ARG\">" . $word . '</A>'; 
            $tmp[$i] = $word;
         }
      }
   }
   $html_out = join('',@tmp);
    return ($html_out);
}

################################################################################
# The line is within the scope of a subroutine or function but NOT a routine
# body.

sub fortran_do_routine_scope {

   if ($routine{$current_rout_name}{inlined_by_foo}) {
      $skip_fortran_out = 1; return;
   }
   if ($routine{$current_rout_name}{template}) {
      $skip_fortran_out = 1; return;
   }

   if ( ! $not_blank) { return; }

   # Don't output inherited self pointer lines; so, the self variable can have
   # its pointer status changed without it affecting the inheritance matching
   # mechanism, so you don't need separate inherit interfaces.
 # if ( defined $current_rout_name && $routine{$current_rout_name}{inherited}
 #     && $routine{$current_rout_name}{being_inherited}) { 
 #    if ($input_line =~ /^\s+self\s+::\s+(PTR|pointer)/) { 
 #       $skip_fortran_out = 1;
 #       return; 
 #    }
 # }

   if ( ! $routine{$current_rout_name}{in_routine_body} ) {
      my $comment;
      ($fortran_out,$comment) = &split_by_comment($fortran_out);
      $fortran_out = &fortran_convert_array_of_arrays($fortran_out);
      &fortran_change_square_brackets;
      $fortran_out = &module_colon_to_fortran($fortran_out);
      $fortran_out = &convert_inherited_type_arg_macros($fortran_out);
      &fortran_change_variable_declarations;
      ######## lines that contain a dot. ###########
      $fortran_out = &dots_to_fortran($fortran_out);
      ######## lines that contain a dot. ###########
      &fortran_change_use_statements;
      &fortran_process_error_management;
      &fortran_store_ensure_statements;
      $fortran_out .= $comment; 
   }
}

################################################################################
# Store ENSURE statements which appear before the first active line and output
# the later at the first active line

sub fortran_store_ensure_statements {

   if ($fortran_out =~ /ENSURE/ ||
       $fortran_out =~ /DIE_IF/ ) {
       if ($routine{$current_rout_name}{first_active_line} == 0) {
           if ($routine{$current_rout_name}{found_local_var_decl} &&
             ! $routine{$current_rout_name}{in_routine_body} &&
             ! $do_tidy ) {
               &report_error("in routine $current_rout_name, put ENSURE statements ".
                   "before local variable declarations:\n\n$input_line");
           }
           $fortran_out =~ s/^\s*/   /;
           if (defined $routine{$current_rout_name}{fortran_ensure_statements}) {
             $routine{$current_rout_name}{fortran_ensure_statements} .= "\n" . $fortran_out;
           } else {
             $routine{$current_rout_name}{fortran_ensure_statements} .=        $fortran_out;
           }
           $fortran_out = '';
           $skip_fortran_out = 1;
       }
   }

}

################################################################################
# The line is within the scope of a subroutine or function, somewhere. i.e the
# scope could be an "if" or "case" but somewhere previously there is an
# enclosing scope which is a routine.
sub do_routine_body {
   if ($do_fortran && $not_blank) { &fortran_do_routine_body; }
   if ($do_html)                  { &html_do_routine_body; }
   if ($do_tidy)                  { &tidy_do_routine_body; }
}

################################################################################
# Replace intitial indent for .vim folding.
sub tidy_do_routine_body {
   # Replace indent
   my $name = $current_rout_name;
   my $indent = $routine{$name}{indent};
   $tidy_out =~ s/^$indent/   /; 

   if ((defined $routine{$name}{first_local_var_decl} ||
                $routine{$name}{first_active_line} == 1) &&
        defined $routine{$name}{ensure_statements}) {
      # Dump previously stored ENSURE statements at first local var
      # or the first active line.
      $tidy_out = $routine{$name}{ensure_statements} . $tidy_out;
      $routine{$name}{ensure_statements} = undef;
#print "dump:";
#print "$tidy_out";
   } elsif ( ($tidy_out =~ /ENSURE/ || $tidy_out =~ /DIE_IF/ ) &&
            ! $routine{$current_rout_name}{in_routine_body}) { 
      # Skip all ENSURES before first active line
      $tidy_out = '';
      $skip_tidy_out = 1;
   }
}

################################################################################
# The line is within the scope of a subroutine or function, somewhere. i.e the
# scope could be an "if" or "case" but somewhere previously there is an
# enclosing scope which is a routine.

sub html_do_routine_body {

  if (defined $current_rout_name &&
      defined $routine{$current_rout_name}{in_routine_body} &&
      $routine{$current_rout_name}{in_routine_body} ) {

      # This is for indenting continuation lines.

      if ($routine{$current_rout_name}{found_continuation} &&
           $html_out !~ /[&] *(!|$)/) {     # Continuation end found
         $routine{$current_rout_name}{found_end_continuation} = 1;
      } else {
         $routine{$current_rout_name}{found_end_continuation} = undef;
      }

      if ($html_out =~ /[&] *(!|$)/ ) {     # Continuation line found
         if (! defined $routine{$current_rout_name}{found_continuation}) {
            $routine{$current_rout_name}{found_continuation} = 1;
            $routine{$current_rout_name}{found_first_continuation} = 1;
         } else {
            $routine{$current_rout_name}{found_first_continuation} = undef;
         }
      } else {
         $routine{$current_rout_name}{found_continuation} = undef;
         $routine{$current_rout_name}{found_first_continuation} = undef;
      }

     # This is to end a previous comment header and add a space line

     if ($routine{$current_rout_name}{first_active_line}) {
        if (! defined $routine{$current_rout_name}{found_var_decl} &&
            ! defined $routine{$current_rout_name}{found_ensure} &&
              defined $routine{$current_rout_name}{found_comment_line}) {
            &html_print('</A>'); # end comment if there, and a break
        }
        &html_print('',0,1); # to LONG only
     }

     # THis is for identing if/else if properly

     if ($scopeunit eq 'if') {
        if ($html_out =~ ' else if') {
           &html_print("</DIV>",1,1); 
           $html_do_indent = 1
         # $html_out = $PREMATCH . " </DIV>else if" . $POSTMATCH . "<DIV CLASS=\"INDENT\">";
        } elsif ($html_out =~ ' else(?= *(?:!|$|;))') {
           &html_print("</DIV>",1,1); 
           $html_do_indent = 1
         # $html_out = $PREMATCH . " </DIV>else" . $POSTMATCH . "<DIV CLASS=\"INDENT\">";
        }
     }

     # THis is for identing select/case properly

     if ($scopeunit eq 'select') {
        if ($html_out =~ "^( *) case(?= *(?:;|[(]|d))" ) {
           &html_print("</DIV>",1,1); 
           $html_do_indent = 1
        #  $html_out = $1 . " </DIV>case" . $POSTMATCH . "<DIV CLASS=\"INDENT\">";
        } 
     }

     # An explicit routine call

     while ($html_out =~ /([A-Z][\w{,}.]*[A-Z0-9}]):(\w+)/g) {
        $html_out = $PREMATCH .
                    '<A CLASS="TYPE" HREF="'.(lc $1).'_short.html">'.$1.'</A>'.
                    ':'.
                    '<A CLASS="ROUTINE" HREF="'.(lc $1).'_short.html#'.$2.'">'.$2.'</A>'. 
                    $POSTMATCH;
     }

     $html_out = &convert_inherited_type_arg_macros($html_out);
#print "1=====> $html_out";
     $html_out = &dots_to_html($html_out);
#print "2=====> $html_out";
     $html_out = &html_replace_routine_args($html_out);
#print "3=====> $html_out";

     if ($html_out =~ /!.*$/) { # replace commments
        $html_out = $PREMATCH . '<A CLASS="COMMENT">' . $& . '</A>';
     }

     # This is to indent continuation lines

     if ($routine{$current_rout_name}{found_first_continuation}) {
        $html_do_indent++;
     }

     # Now print out the line here ...

     if ($skip_html_out != 1) {
     if ($html_out =~ /<DIV[^>]*>$/) { &html_print($html_out,1,1); }
     else                            { &html_print($html_out,0,1); }
     }

     # Deal with indents of do, if, select, forall, and so on.
     # The corresponding </DIV> is done in the do_new_end_scope.

     if ($html_do_indent==1) { &html_print("<DIV CLASS=\"INDENT\">",1,1); }
     if ($html_do_indent==2) { &html_print("<DIV CLASS=\"INDENT\"><DIV CLASS=\"INDENT\">",1,1); }
     if ($routine{$current_rout_name}{found_end_continuation}) {
        &html_print("</DIV>",1,1); 
     }

  }

}

################################################################################
# Change special HTML characters such as < and > before anything else. Any
# others? Put em here.

sub html_change_special_chars {
   my $html_out = $_[0];
   $html_out =~ s/>/\&gt;/;
   $html_out =~ s/</\&lt;/;
   return ($html_out);
}

################################################################################
# The line is within the scope of a subroutine or function, somewhere. i.e the
# scope could be an "if" or "case" but somewhere previously there is an
# enclosing scope which is a routine.

sub fortran_do_routine_body {

  if ($routine{$current_rout_name}{inlined_by_foo}) {
      $skip_fortran_out = 1; return;
  }
  if ($routine{$current_rout_name}{template}) {
      $skip_fortran_out = 1; return;
  }

  if ($routine{$current_rout_name}{in_routine_body} ) {

     my $comment;
     ($fortran_out,$comment) = &split_by_comment($fortran_out);
   
     $fortran_out = &fortran_convert_array_of_arrays($fortran_out);
     &fortran_change_square_brackets;
     $fortran_out = &module_colon_to_fortran($fortran_out);
     $fortran_out = &convert_inherited_type_arg_macros($fortran_out);
   
     ######## lines that contain a dot. ###########
     $fortran_out = &dots_to_fortran($fortran_out);
     ######## lines that contain a dot. ###########
   
     # Ad hoc stuff here ...
   
     &fortran_process_error_management;
     &fortran_process_return;
     &fortran_process_case_statements;
     &fortran_add_stack_macro; 
   
     $fortran_out .= $comment; 
  }

}

################################################################################
# The line is within the scope of a program.
sub do_program_scope {
   if ($do_fortran && $not_blank) { &fortran_do_program_scope; }
   if ($do_html)                  { &html_do_program_scope; }
}

################################################################################
# The line is within the scope of a program.
sub html_do_program_scope {
   &html_do_routine_scope;
   &html_do_routine_body;
}

################################################################################
# The line is within the scope of a program.
sub fortran_do_program_scope {

  $name = lc($module_name);
  $current_rout_name = lc($module_name);
  %routine = ();
  $routine{$name}{real_name} = $name;
  $routine{$name}{short_name} = $name;

  my $comment;
  ($fortran_out,$comment) = &split_by_comment($fortran_out);

  &fortran_add_default_initialisation;
  &fortran_change_variable_declarations;

  $fortran_out = &fortran_convert_array_of_arrays($fortran_out);
  &fortran_change_square_brackets;
  $fortran_out = &module_colon_to_fortran($fortran_out);

  ######## lines that contain a dot. ###########
  $fortran_out = &dots_to_fortran($fortran_out);
  ######## lines that contain a dot. ###########

  &fortran_process_error_management;
  &fortran_process_case_statements;
  &fortran_add_include_files;
  &fortran_change_use_statements;

#  &fortran_add_default_initialisation;
#  &fortran_change_variable_declarations;
#
#  ######## lines that contain a dot. ###########
#  $fortran_out = &dots_to_fortran($fortran_out);
#  ######## lines that contain a dot. ###########
#
#  &fortran_process_case_statements;
#  &fortran_process_error_management;
#  &fortran_add_include_files;
#  &fortran_change_use_statements;
#  &fortran_change_square_brackets;
#  $fortran_out = &fortran_convert_array_of_arrays($fortran_out);
#  $fortran_out = &module_colon_to_fortran($fortran_out);

  $fortran_out .= $comment; 
}

################################################################################
# The line is within the scope of a module.
sub do_module_scope {
   if ($do_fortran && $not_blank) { &fortran_do_module_scope; }
   if ($do_html)                  { &html_do_module_scope; }
}

################################################################################
# The line is within the scope of a module.
sub html_do_module_scope {

   if ($html_out =~ /implicit none/) { &html_put_use_list; }
   else                              { &html_do_module_variables; }

}

################################################################################
# The line is within the scope of a module.
sub html_do_module_variables {

   if (! defined $module{$module_name}{found_module_var}) {
      if ($html_out =~ /^\s*(#|$)/) {
         return;
      } else {
         if (defined $module{$module_name}{found_module_interface}) {
           &report_error("declare any explicit module interfaces " .
                "after any module variables.");
         }
         $module{$module_name}{found_module_var} = 1;
   
         &html_print("</DIV>",1); # End USE list
   
         &html_print("\n",1);
         &html_print("\n",1);
         &html_print("<BR><H2>Module data and/or variables:</H2>",1);
         &html_print("<DIV CLASS=\"INDENT\">");
      }
   }

   # This is for indenting continuation lines.

   if ($module{$module_name}{found_continuation} &&
        $html_out !~ /[&] *(!|$)/) {     # Continuation end found
      $module{$module_name}{found_end_continuation} = 1;
   } else {
      $module{$module_name}{found_end_continuation} = undef;
   }

   if ($html_out =~ /[&] *(!|$)/) {     # Continuation line found
      if (! defined $module{$module_name}{found_continuation}) {
         $module{$module_name}{found_continuation} = 1;
         $module{$module_name}{found_first_continuation} = 1;
      } else {
         $module{$module_name}{found_first_continuation} = undef;
      }
   } else {
      $module{$module_name}{found_continuation} = undef;
      $module{$module_name}{found_first_continuation} = undef;
   }

   # This is a comment header ....

   if ($html_out =~ s/^ *!//) {         

      if (! defined $module{$module_name}{found_comment_line} ) {
         $module{$module_name}{found_comment_line} = 1;
         $html_out = "<A CLASS=\"COMMENT\">... $html_out"; # A routine comment
         &html_print($html_out,1);
      } else {
         &html_print($html_out,1);
      }

   # This is a variable declaration ....

   } elsif ($html_out =~ '(.*)::(.*)') { 

      my $left = $1;
      my $right = $2;

      #Do right side.  Link to any types we know of.
      if ($left !~ '^ *self') {
         $right =~ /([A-Z][\w{,}.]*[A-Z0-9}])/;
         $right = $PREMATCH . '<A CLASS="TYPE" HREF="' . (lc $1) . '_short.html">' . $1 . 
                  '</A>' .  $POSTMATCH;
      }

      #Merge them back together.
      $html_out = $left . '::' . $right;

      if (defined $module{$module_name}{found_comment_line}) {
         $module{$module_name}{found_comment_line} = undef;
         &html_print('</A>'); # end comment if there, and a break
      }

      &html_print($html_out,0); # <===========

      if ($module{$module_name}{found_first_continuation}) {
         &html_print("<DIV CLASS=\"INDENT\">",1); 
      } elsif ($module{$module_name}{found_end_continuation}) {
         &html_print("</DIV>",1); 
      }

   # Don't know what it is ... probably a continuation line ...

   } else {

      if (defined $module{$module_name}{found_comment_line}) {
         $module{$module_name}{found_comment_line} = undef;
         &html_print('</A>'); # end comment if there, and a break
      }

      &html_print($html_out,0);

      if ($module{$module_name}{found_first_continuation}) {
         &html_print("<DIV CLASS=\"INDENT\">",1); 
      } elsif ($module{$module_name}{found_end_continuation}) {
         &html_print("</DIV>",1); 
      }

   }

}

################################################################################
# The line is within the scope of a module.
sub fortran_do_module_scope {

   my $comment;
   ($fortran_out,$comment) = &split_by_comment($fortran_out);
#print "IN module scope ----";
#print "-----> out = $fortran_out";
#print "-----> com = $comment";
   &fortran_add_default_initialisation;
#print "-----> out = $fortran_out";
   &fortran_add_include_files;
#print "-----> out = $fortran_out";
   &fortran_change_variable_declarations;
#print "-----> out = $fortran_out";
   &fortran_change_use_statements;
#print "-----> out = $fortran_out";
   &fortran_change_square_brackets;
   $fortran_out = &fortran_convert_array_of_arrays($fortran_out);
   $fortran_out .= $comment; 

}

################################################################################
# The line is within the scope of a type declaration.
sub do_type_scope {
   if ($do_fortran && $not_blank) { &fortran_do_type_scope; }
}

################################################################################
# The line is within the scope of a type declaration.
sub fortran_do_type_scope {

   my $comment;
   ($fortran_out,$comment) = &split_by_comment($fortran_out);

   if ($scopeunit eq 'array type') {
      $fortran_out = ''; # Do not output array type scopes.
   }
   else {
      &fortran_add_default_initialisation;
      &fortran_change_variable_declarations;
      &fortran_change_square_brackets;
      # Remove private attributes in type declarations
      $fortran_out =~ s/,\s*private\s*//;
   }

   $fortran_out .= $comment; 

}

################################################################################
# Add macros include file, and interface include file 
sub fortran_add_include_files {
   if ($fortran_out =~ 'implicit none') {
      $fortran_out .= "\n\n#  include \"macros\"\n";
      if (! $is_program) {
         $fortran_out .=  "#  include \"${fortranintfile}\"\n";
      }
      if  ( $module_name ne 'TYPES' && ! $is_program) {
         if ($module_is_intrinsic) {
            $fortran_out .= "\n" .
               "#  define SELF_TYPE_SIZE ${module_fort_type}_SIZE";
               "!  define SELF_TYPE_SIZE ${module_fort_type}_SIZE";
         }
         elsif (! $module_is_array ) {
            $fortran_out .= "\n" .
               "#  define SELF_TYPE_SIZE ${tonto_type_info{$module_name}{tonto_size}}";
               "!  define SELF_TYPE_SIZE ${tonto_type_info{$module_name}{tonto_size}}";
         } else {
            $fortran_out .= "\n" .
               "#  define ELEMENT_TYPE_SIZE ${tonto_type_info{$module_name}{tonto_element_size}}\n" .
               "#  define ARG1_TYPE_SIZE ${tonto_type_info{$module_name}{tonto_element_size}}";
               "!  define ELEMENT_TYPE_SIZE ${tonto_type_info{$module_name}{tonto_element_size}}\n" .
               "!  define ARG1_TYPE_SIZE ${tonto_type_info{$module_name}{tonto_element_size}}";
         }
      }
   }
}

################################################################################
# Change the variable declaration order and the array type declarations as well,
# e.g.  VEC{REAL}.DYLAN -> VEC_REAL_DYLAN(:) 

sub fortran_change_variable_declarations {

   if ($fortran_out !~ m'\s+::\s+'o) { return; } # variable declaration line.

   my ($pre,$post,$var1,$vars,$type_name,$attr,$assign,$command);

   $fortran_out =~/(\w+)/;              # Get the variable names
   $pre = $PREMATCH;
   $var1 = $1; 
   $vars = $1; 
   $post = $POSTMATCH;
   
   $post =~/(^.*)(\s+::\s+)/;
   if (defined $1) { $vars .= $1; }     # More than one variable
   $post = $POSTMATCH;
   
   $type_name = '';                     # Get type name
   $post =~ '^([*\w{,}.()-=+/:%]*[\w})][*]?)';
   # this is not working for declarations that include whitespace.  It really
   # should check for bracketed things and ignore whitespace within those.
   if (defined $1) { $type_name = $1; }
   $post = $POSTMATCH;
   
   $attr = '';                          # Get variable attributes
   if ($post =~ /^\s*(.*?)((?:DEFAULT)|(?:=)|(?:;))/) {
      $attr = $1; $post = $2.$POSTMATCH; 
   } else {
      $attr = $post; $post = ''; 
      $attr =~ s/^\s*//;
   }
   
   $assign = '';                        # Get any assignment
   if ($post =~/^\s*(DEFAULT.*)/) {
      $assign = ' '.$1; $post = $POSTMATCH; }
   if ($post =~/^\s*(=.*)/) {
      $assign = ' '.$1; $post = $POSTMATCH; }
   
   $command = '';                       # Get any appended commands
   if ($post =~/^\s*(;\s*.*)/) { $command = $1; }
   
   if ($type_name eq 'PTR'   ||
       $type_name eq 'IN'    ||
       $type_name eq 'INOUT' ||
       $type_name eq 'OUT'   ||
       $type_name =~ m/^pointer$/i ||
       $type_name =~ m/^target$/i ||
       $type_name =~ m/^save$/i ||
       $type_name =~ m/^allocatable$/i)   {
      if ($var1 ne 'self') {
        &report_error("only \"self\" can be declared with first attribute \"$type_name\".");
      }
      $fortran_out = "$pre$type_name$attr :: $vars$assign$command"; 
      return;
   }

   my $var_info  = $local_var_info{$var1};

   my $fortran_type_decl = $var_info->{fortran_type_decl};
   my $type_ptr_part     = $var_info->{type_ptr_part};
   my $is_routine_arg    = $var_info->{is_routine_arg};
   my $type_size_part    = $var_info->{type_size_part};
   my $type_head_name    = $var_info->{type_head_name};
   my $n_type_args       = $var_info->{n_type_args};
   my $type_arg_1        = $var_info->{type_arg}[1];

   if (! defined $fortran_type_decl) {
     &report_error("variable \"$var1\" does not have a known type.");
   }

   my $ptr = "";
   if ($type_ptr_part eq '*' &&
       $attr !~ /(PTR|pointer)/) { $ptr = ", PTR"; }

   $fortran_out = "$pre$fortran_type_decl$ptr$attr :: $vars$assign$command"; 
   $fortran_out =~ s/\s*::\s*/ :: /;
}

################################################################################
# Work out the fortran type declarations, including array size part. This
# routine needs to know whether the type declaration is for a routine argument
# or not.

sub make_fortran_type_declarations {

   my ($type_name,
       $sub_type_name,
       $type_size_part,
       $type_head_name,
       $type_arg_1,
       $is_routine_arg,
       $is_intrinsic_scalar,
       $is_array) = @_;     # <------------

   my $fortran_type_name;
   my $fortran_type_decl;
   my $fortran_mod_name, 
   my $fortran_self_decl;

   $fortran_type_name = $type_name;
   $fortran_type_name =~ s/[{,.]/_/g;  # Replace open curlies and commas with underscore
   $fortran_type_name =~ s/[}]//g;     # Eliminate the close ciurlies
   $fortran_type_name =~ s/[(].*[)]$//;# Remove any size part at the end

  if ($sub_type_name eq '') { $fortran_mod_name = "${fortran_type_name}"; }
  else                      { $fortran_mod_name = "${fortran_type_name}_${sub_type_name}"; }

#print "------ in & fortran_type_decl -----";
#print "line -----------> $input_line";
#print "full_type_name  = $type_name";
#print "type_size_part  = $type_size_part";
#print "type_head_name  = $type_head_name";
#print "type_arg_1      = $type_arg_1";
#print "arg_1_decl      = $arg_1_decl";
#print "is_routine_arg  = $is_routine_arg";
#print "fortran_mod_name  = $fortran_mod_name";
#print "fortran_type_name = $fortran_type_name   ";
#print "sub_type_name     = $sub_type_name   ";

   #############################################################################
   if ($type_name eq 'BSTR') {
     &report_error("Do not use BSTR to declare variables, use STR(len=BSTR_SIZE).");
   }
   #############################################################################
   elsif ($type_name =~ '^CHR') {            
     &report_error("Do not use CHR to declare variables, use STR(len=1).");
   }
   #############################################################################
   elsif  ($is_intrinsic_scalar) {  # For INTRINSIC scalar variable declarations
      ($fortran_type_decl,$fortran_self_decl) =
         &make_scalar_fortran_types($type_name,$type_size_part,$is_routine_arg);
   }

   # For ARRAY declarations ...  # #############################################
   elsif ($is_array) {                               

      if (! defined $type_arg_1) {
        &report_error("array type does not have type argument.");
      }

      my ($arg_1_decl,$arg_1_self_decl,$type_size_part) =
         &make_scalar_fortran_types($type_arg_1,$type_size_part,$is_routine_arg);

      my $dim;
      for ($dim = 1; $dim <= @tonto_intrinsic_array_type_names; $dim++) {  
         # $pattern is VEC, MAT, MAT3, MAT4 ... 
         my $pattern = $tonto_intrinsic_array_type_names[$dim]; 
         next if ($type_head_name ne $pattern);
         my $ass = $tonto_assumed_array_part{$pattern};
         if ($type_size_part eq '') { 
            $fortran_type_decl = "$pattern($arg_1_decl,$ass)";
         } else {
            $fortran_type_decl = "$pattern($arg_1_decl,$type_size_part)";
         }
         $fortran_self_decl = "$pattern($arg_1_self_decl,$ass)";
         last;
      }
   }
   #############################################################################
   else {                   # For NONINTRINSIC non-array variable declarations
      $fortran_type_decl = "type(${fortran_type_name}_TYPE)";
      $fortran_self_decl = $fortran_type_decl;
   }

   return ($fortran_type_name,
           $fortran_type_decl,
           $fortran_mod_name, 
           $fortran_self_decl);
}

################################################################################
# If $type_name is *NOT* intrinsic, this routine returns $fortran_type_decl
# as stored in tonto_type_info{$type_name}{fortran_type_decl}. The kind length
# variables are returned as blank, and the $type_size_part is returned
# unchanged. If $type_name *IS* intrinsic scalar (e.g.  "STR{7}") and there is a
# corresponding $type_size_part which may specify a len= specifier (e.g.
# "len=3,:,:"), and $is_routine_arg tells whether the $type_name is intended to
# declare a routine arg or not, THEN return the $fortran_type_decl (e.g.
# "STR(kind=7,len=3)" for $type_name being "STR{7}" and $type_size_part being
# "len=3,:,:"), the $fortran_self_decl (e.g.  "STR(kind=7,len=*)" for the
# previous example), and a modified $type_size part which has the len= specifier
# removed (e.g. ":,:" for the previous example). 
# NOTE: the $type_size_part need not correspond to that for a scalar type.
# NOTE: the len= specifier (if present) MUST be the first thing in the
# $type_size_part, and it overrides $is_routine_arg which leads to len=*.

sub make_scalar_fortran_types {

   my ($type_name,$type_size_part,$is_routine_arg) = @_;

   my ($fortran_type_decl,$kind);

   $kind = "";
   if ($type_name =~ "^(STR)({.*})?"  ||  # For INTRINSIC types
       $type_name =~ "^(BIN)({.*})?"  ||  # Kind is specified in curlies
       $type_name =~ "^(INT)({.*})?"  ||
       $type_name =~ "^(REAL)({.*})?" ||
       $type_name =~ "^(CPX)({.*})?"  ) {
      $fortran_type_decl = $1;      
      if (defined $2 && $2 ne '') {
         $kind = $2;
         $kind =~ /[{](.*)[}]/;
         $kind = "kind=$1,"; # note comma
      }
   } else {                               # For NONINTRINSIC types
      # This part should be entered only from the array type region of
      # &make_fortran_type_declarations. Therefore, scalar $type_name will be a
      # type arg, and should have been defined previously in the types.foo file
      # -- unless it is a dummy type being analysed in a get_from statement.
      $fortran_type_decl = $tonto_type_info{$type_name}{fortran_type_decl}; # <========
      # Die if it hasn't been defined ... and it isn't a dummy being analysed
      if (! defined $fortran_type_decl) {
         if ($newscopeunitfound) {
           $fortran_type_decl = ''; # This should not be used, its in a get_from
         } else { 
           &report_error("fortran type name for type \"$type_name\" not yet defined.");
         }
      }
   }

   my $kind_length_part = "";        
   my $self_kind_length_part = "";                 
   if ($fortran_type_decl eq 'STR') {     # For STR type ... can have kind= and len=
      # Users beware: explicit len= overrides routine arguments len=*. Trust foo!
      # Note the $type_size_part gets modified here.
      if    ($type_size_part =~ s/^ *len *= *(.*?),//) { $kind_length_part = "(${kind}len=$1)"; }
      elsif ($type_size_part =~ s/^ *len *= *(.*?)$//) { $kind_length_part = "(${kind}len=$1)"; }
      elsif ($is_routine_arg==1)                       { $kind_length_part = "(${kind}len=*)"; }
      else                                             { $kind_length_part = "(${kind}len=STR_SIZE)"; }
      $self_kind_length_part = "(${kind}len=*)";
   }
   elsif ($type_size_part =~ /^ *len *= */) {
     &report_error("cannot specify len= for intrinsic scalar type \"$type_name\".");
   }
   elsif ($kind ne '') {                  # Must be a non-string INTRINSIC kind= declaration
      $kind =~ s/,$//;      # remove comma
      $kind_length_part      = "(${kind})";             # Insert kind= like len=
      $self_kind_length_part = "(${kind})";             # ... for self declaration as well
   }  

   return ($fortran_type_decl . $kind_length_part,      # Normal declaration
           $fortran_type_decl . $self_kind_length_part, # Self declaration
           $type_size_part);
}

################################################################################
## Change the lower case use statements by appending _MODULE to used modules.
## With the only clause, add an underscore to the used routine, or if not
## using the full generic mechanism, preprend the module name as well

sub fortran_change_use_statements {

  if ($fortran_out =~ ' use ') {
      if ($fortran_out !~ /^\s*use\s+TYPES/) {
         $fortran_out =~ s/^[ ]*use[ ]+([A-Z][\w,{}]*[\w}])/   use $1_MODULE/s;
      } else {
         $fortran_out =~ s/^[ ]*use[ ]+([A-Z][\w,{}]*[\w}])/   use $tonto_type_info{$1}{fortran_mod_name}_MODULE/s;
      }
      if ($do_generic) {
         $fortran_out =~ s/^ +use +.*only: *\w+[^ _]$/$&_/;
      } else {
         $fortran_out =~ s/^ *use +(\w+)_MODULE *, *only: *(\w+[^_]) *$/   use $1_MODULE, only: $1_$2/;
      }
  }

}

################################################################################
## Change square brackets to array constructors. (If preceeded by a backslash,
## then do not do the replacement). 

sub fortran_change_square_brackets {

  $fortran_out =~ s/([^\\])\[/$1(\//go; # brackets [ ] are array constructors
  $fortran_out =~ s/([^\\])\]/$1\/)/go; # 
  $fortran_out =~ s/\\\[/[/go;          # ... unless preceeded by back slash
  $fortran_out =~ s/\\\]/]/go;  

}

################################################################################
# Generate the routine line. The line is within the scope of a "contains" block.
sub do_new_routine_scope {
   if ($do_fortran) {  &fortran_do_new_routine_scope; }
   if ($do_html)    {  &html_do_new_routine_scope; }
}

################################################################################
# Generate the fortran routine statement. The line is within the scope of a 
# "contains" block.
sub fortran_do_new_routine_scope {

  if ($routine{$current_rout_name}{inlined_by_foo}) {
      $skip_fortran_out = 1; return;
  }
  if ($routine{$current_rout_name}{template}) {
      $skip_fortran_out = 1; return;
  }

  my ($pre,$attr,$rout_type,$name,$args,$real_name,$result);

  $name = $current_rout_name;
  $pre = $routine{$name}{indent};
  $attr = '';
  if    (defined $routine{$name}{always_elemental}) { $attr = 'ALWAYS_ELEMENTAL '; }
  elsif (defined $routine{$name}{elemental})        { $attr = 'ELEMENTAL '; }
  elsif (defined $routine{$name}{always_pure})      { $attr = 'ALWAYS_PURE '; }
  elsif (defined $routine{$name}{pure})             { $attr = 'PURE '; }
  if    (defined $routine{$name}{recursive})        { $attr .= 'recursive '; }

  $rout_type = '';
  if    (defined $routine{$name}{function})         { $rout_type = 'function'; }
  else                                              { $rout_type = 'subroutine'; }
  $args = $routine{$name}{arg_string};
  $real_name = $routine{$name}{real_name};

  $result = '';
  if (defined $routine{$name}{function_result}) {
    $result = " result(" . $routine{$name}{function_result} . ")";
  }

  my $mod = "";
  if (!$do_generic && $parentscope !~ 'interface') { $mod = "${module_fort_name}_"; }

  $fortran_out = "${pre}${attr}${rout_type} ${mod}${real_name}${args}${result}";

  if ( ! (defined $routine{$name}{functional} || 
          defined $routine{$name}{routinal} ||
          defined $routine{$name}{selfless})) {
    $fortran_out .= "\n${pre}${module_self_decl} :: self";
  }
}

################################################################################
# Convert an explicit module call into Fortran.
# Takes a string as its only argument, and returns the Fortran version.
sub module_colon_to_fortran {

  my $X = $_[0];

  # in case of no colon
  if ($X !~ m'[:]'o) {return $X;} 

  # skip "include" lines, don't want any filenames changed.
  if ($X =~ m'include'o && 
      $X =~ m'^(?:\s*|[#])include\s+[\"\'](?:[^\"\']+)[\"\']'o) {
    return $X;
  }

  while ($X =~ /([(,=*+-]\s*)([A-Z][A-Z_0-9{,}.]+):(\w+)/g) { # A function call
     my $pre = $PREMATCH.$1;
     next if ($pre =~ /"$/); # skip quoted calls
     my $last = $pre; $last = chop($last);
     if ($last eq '.') { next };
#print "X = $X";
#print "pre = $pre";
#print "last = $last";
     my $rout_type = $2; 
     my $rout = $3; 
     my $post = $POSTMATCH;
     my %info = &analyse_type_name($rout_type);
     &analyse_type_name($rout_type);
#print "X = $X";
#print "rout = $rout";
#print "rout_type = $rout_type";
     $rout_type = $info{type_name}; # reset to generic type
     if (! defined $tonto_type_info{$rout_type}) {
       &report_error("type \"$rout_type\" in explicit module call was not declared in \"$typesfile\".");
     }
     $rout_type = $info{full_type_name}; # called routines labelled by full type name
     my $fortran_type_name = $info{fortran_type_name};
     my $fortran_mod_name  = $info{fortran_mod_name};
     $called_routines{$rout_type}{$rout}{fortran_mod_name}  = $fortran_mod_name;
     $called_routines{$rout_type}{$rout}{fortran_type_name} = $fortran_type_name;
     $called_routines{$rout_type}{$rout}{function_call} = 1;
     if ($do_generic) { $X = $pre.$rout.$post; } 
     else             { $X = $pre.$fortran_mod_name."_".$rout.$post; }
     if ($do_routine_calls && $pass==2) {
          print RCFILE "   $rout_type:$rout";
     }
  }

  if ($X =~ /(?<!.)([A-Z][A-Z_0-9{,}.]+):(\w+)/) { # Routine call, anywhere not a function
     my $pre = $PREMATCH;                          # and not following a dot
     my $rout_type = $1; 
     my $rout = $2; 
     my $post = $POSTMATCH;
     my %info = &analyse_type_name($rout_type);
     &analyse_type_name($rout_type);
     $rout_type = $info{type_name}; # reset to generic type
     if (! defined $tonto_type_info{$rout_type}) {
       &report_error("type \"$rout_type\" in explicit module call was not declared in \"$typesfile\".");
     }
     $rout_type = $info{full_type_name}; # called routines labelled by full type name
     my $fortran_type_name = $info{fortran_type_name};
     my $fortran_mod_name  = $info{fortran_mod_name};
     $called_routines{$rout_type}{$rout}{fortran_mod_name}  = $fortran_mod_name;
     $called_routines{$rout_type}{$rout}{fortran_type_name} = $fortran_type_name;
     if ($do_generic) { $X = $pre."call ".$rout."_".$post; } 
     else             { $X = $pre."call ".$fortran_mod_name."_".$rout.$post; }
     if ($do_routine_calls && $pass==2) {
          print RCFILE "   $rout_type:$rout";
     }
  }

  return $X;

}

################################################################################
# Convert the dot notation into Fortran.
# Takes a string as its only argument, and returns the Fortran version.
sub dots_to_fortran {

  my $X = $_[0];

  # in case of no dots
  if ($X !~ m'[.]'o) {return $X;} 

  # skip "include" lines, don't want any filenames changed.
  if ($X =~ m'include'o && 
      $X =~ m'^(?:\s*|[#])include\s+[\"\'](?:[^\"\']+)[\"\']'o) {
    return $X;
  }

  my($pre,$left,$right,$i);
  my($rout,$post,$fixedpost,$arg,$call,$underscore,$arg_type);
  my ($fortran_type_name,$fortran_mod_name,$sub_mod_name);

  $i = 0;
  THIS : while ($i < length $X) {
    if ((substr $X,$i,1) eq '.') {
      $left = substr $X,0,$i;
      $right = substr $X,$i+1;
      if (! &outside_of_string($left)) { next THIS; }

      # What is to the right of the dot - object feature and other stuff.
      if ($right !~ m'^([A-Z_]+:)?([a-zA-Z_]\w*)(.*)'o) {next THIS};
      undef $sub_mod_name;
      if (defined $1) {  # If preceded by a colon this is the submodule name
         $sub_mod_name = $1; 
         $sub_mod_name =~ s/:$//; 
      }
      $rout = $2;
      $post = $3;
      $fixedpost = $3;

      # Separate out the argument from the previous stuff on the line.
      $arg = &get_last_foo_object($left);
      if ($arg eq '') {
        # if last object is null, then set it to 'self'.
        $arg = 'self';
        $pre = $left;
      } else {
        $left =~ /(\Q$arg\E)$/;
        $pre = $PREMATCH;
      }

      # determine if subroutine call or not.
      # subroutine call must have a new line, semicolon or right-bracket
      # before it.
      # round bracket?
      if ($pre =~ m'((?:;|^|\))\s*)$'o) {$call = 'call ';}
      else                              {$call = '';}

      if (&has_field($arg, $rout)) {              # $rout is a type field component
         # $i does not change if we change the dot to a %.
         $X = join('',$pre,$arg,'%',$rout,$post);

      } else {                                    # $rout is a routine call ...

        my $done = 0;
        # Deal with some intrinsics by explicit inlining
        foreach $i (@tonto_intrinsic_functions) {
          if ($rout =~ m/^$i$/) {
            $rout = $i;
            $underscore = '';
            $done = 1;
            last;
          }
        }

        if (! $done && $rout =~ m'^dim([1234567]?)$'o) {   # Modify dim statements explicitly
          if (defined $1 && $1 ne '') { $arg .= ",$1"}
          $rout = 'size';
          $underscore = '';
          $done = 1;
        } elsif ($post !~ '^[(]' && $rout =~ m'^created$'o) {   
                                                  # Modify argumentless "created" statements explicitly
          $rout = 'associated';
          $underscore = '';
          $done = 1;
        } elsif ($post !~ '^[(]' && $rout =~ m'^destroyed$'o) { 
                                                  # Modify argumentless "destroyed" statements explicitly
          $rout = 'NOT associated';
          $underscore = '';
          # We might have introduced a "NOT NOT".
          if ($pre =~ s/NOT\s*$// || $pre =~ s/\.NOT\.\s*$//) {
            $rout = 'associated';
          }
          $done = 1;
        }

        # Deal with a "normal" routine
        if (! $done) {                            # Do a normal routine
          # add to use list.
          $arg_type = $local_var_info{$arg}{full_type_name};
          if (defined $arg_type) {
             if (defined $sub_mod_name) {         # arg wont be a local_var
                $arg_type = $arg_type . '.' . $sub_mod_name; 
                my %info = &analyse_type_name($arg_type);
                $fortran_type_name = $info{fortran_type_name}; 
                $fortran_mod_name  = $info{fortran_mod_name}; 
             } else {
                $fortran_type_name = $local_var_info{$arg}{fortran_type_name}; 
                $fortran_mod_name  = $local_var_info{$arg}{fortran_mod_name}; 
             }
          } else {
             $arg_type = &type_of_this($arg);
             if (defined $sub_mod_name) {         # arg wont be a tonto_type
                $arg_type = $arg_type . '.' . $sub_mod_name; 
                my %info = &analyse_type_name($arg_type);
                $fortran_type_name = $info{fortran_type_name}; 
                $fortran_mod_name  = $info{fortran_mod_name}; 
             } else {
                $fortran_type_name = $tonto_type_info{$arg_type}{fortran_type_name}; 
                $fortran_mod_name  = $tonto_type_info{$arg_type}{fortran_mod_name}; 
             }
          }
          if (! defined $fortran_mod_name) {
             &report_error("type \"$arg_type\" for variable \"$arg\" was not declared in \"$typesfile\".");
          }
          $called_routines{$arg_type}{$rout}{fortran_mod_name}  = $fortran_mod_name;
          $called_routines{$arg_type}{$rout}{fortran_type_name} = $fortran_type_name;
          if ($do_routine_calls && $pass==2) {
             my $call = "$arg_type:$rout";
             my $short_name = $routine{$current_rout_name}{short_name};
           # if (! defined($current_rout_name)) { die "short name not defined"; }
           # if (! defined($short_name)) { die "short name not defined"; }
             if (! &routine_calls_this_routine($short_name,$call)) {
                print RCFILE "   $call";
                push @{$routine_calls{$short_name}}, $call;
             }
          }
          if ($do_generic) {                      # Underscore, always generic
            $underscore = '_';
          } else {
          # If no generic interfaces are being used, scrub interface
          # and place explicit type in front of routine name
            $rout = $fortran_mod_name . '_' . $rout;
            $underscore = '';
          }
        }

        # check for other arguments to the function call.
        if ($fixedpost !~ s'^[(]','o)    { $fixedpost = ')' . $fixedpost; }

        $X = join('',$pre,$call,$rout,$underscore,'(',$arg,$fixedpost);
        # for a routine call, $i will increase by the length of ${rout} plus
        # one for the bracket.  If there is no underscore, then decrease by 1.
        $i += (length (join('',$call,$rout,$underscore)) - 1);
      }
    }
  } continue {
    $i++;
  }
  return $X;

}

################################################################################
# Convert the dot notation into HTML.
# Takes a string as its 1st argument, and returns the HTML version.
# If $in_comment is set, the dots are conveted within a comment.
sub dots_to_html {

   my ($X,$in_comment) = @_;
   my $Y = $X;
 
   # in case of no dots
   if ($X !~ m'[.]'o) {return $X;} 
 
   # skip "include" lines, don't want any filenames changed.
   if ($X =~ m'include'o && 
       $X =~ m'^(?:\s*|[#])include\s+[\"\'](?:[^\"\']+)[\"\']'o) {
     return $X;
   }
 
   my($pre,$left,$right,$i);
   my($rout,$post,$arg,$arg_type,$lc_arg_type,$match);
 
   $i = 0;
   THIS : while ($i < length $X) {
      if ((substr $X,$i,1) eq '.') {
         $left = substr $X,0,$i;
         $right = substr $X,$i+1;
         if (! &outside_of_string($left)) { next THIS; }
   
         # What is to the right of the dot - object feature and other stuff.
         if ($right !~ m'^([a-zA-Z_]\w*)(.*)'o) {next THIS};
         $rout = $1;
         $post = $2;
   
         # Separate out the argument from the previous stuff on the line.
         $arg = &get_last_foo_object($left);
         if ($arg eq '') {
            # if last object is null, then set it to 'self'.
            $arg = 'self';
            $pre = $left;
            $i += 4;
            $X = join('',$pre,$arg,'.',$rout,$post);
         } else {
            $left =~ /(\Q$arg\E)$/;
            $pre = $PREMATCH;
         }

         $arg_type = $local_var_info{$arg}{full_type_name};
         if (! defined $arg_type) {
             $arg_type = &type_of_this($arg);
         }
         $lc_arg_type = lc $arg_type;

         # match is the same as post but for matching in an regex
         $match = $post;
         $match =~ s/\(/\\(/g; $match =~ s/\)/\\)/g;
         $match =~ s/\{/\\{/g; $match =~ s/\}/\\}/g;
         $match =~ s/\[/\\[/g; $match =~ s/\]/\\]/g;
         $match =~ s/\./\\./g; $match =~ s/\?/\\?/g;
         $match =~ s/\*/\\*/g; $match =~ s/\+/\\+/g;
         $Y =~ "(.*?\\.)$rout$match";
         if (defined $1) {
           $Y = $1;
         } else {
           $Y = '';
         }
   
         if (&has_field($arg, $rout)) {              # $rout is a type field component

            if ($in_comment) {
               $Y .= "</A><A CLASS=\"TYPEFIELD\" HREF=\"${lc_arg_type}_short.html#$rout\">" 
                  . $rout . "</A><A CLASS=\"COMMENT\">" .  $post;
            } else {
               $Y .= "<A CLASS=\"TYPEFIELD\" HREF=\"${lc_arg_type}_short.html#$rout\">" 
                  . $rout . "</A>" .  $post;
            }
   
         } else {                                    # $rout is a routine call ...

            if (defined $tonto_type_info{$arg_type}) {
            if ($in_comment) {
               $Y .= "</A><A CLASS=\"ROUTINE\" HREF=\"${lc_arg_type}_short.html#$rout\">" 
                  . $rout . "</A><A CLASS=\"COMMENT\">" .  $post;
            } else {
               $Y .= "<A CLASS=\"ROUTINE\" HREF=\"${lc_arg_type}_short.html#$rout\">" 
                  . $rout . "</A>" .  $post;
            }
            }

         }
      }
   } continue {
      $i++;
   }
   return $Y;

}

###############################################################################
# This routine returns the last single object of the string i.e. the object that
# has been "dotted" by dot notation. The search for this object moves from the
# end of the string to the front. During the search we must test to see that
# brackets are matched. The search ends at the front of the string, or when a
# non alpha, non dot, non %, non bracket character is encountered.

sub get_last_foo_object {
    my ($i,$this,$char,$ok);
    $ok = '';
    $i = (length $_[0]) -1;
    while ($i > -1) {
      $this = substr $_[0],$i;
      $char = substr $_[0],$i,1;
      if (&has_matching_brackets($ok)) { # check for an unmatched opening bracket.
        if ($char !~ '[\w\.%\)]') {last}
      }
      if (! &has_matching_brackets($this)) { # still within closed brackets.
        $ok = $this;
        next;
      }
      # from now on the brackets are closed.
      if ($this =~ '^[\w\.%(]') { # part of an object
        $ok = $this;
        next;
      } else { # finished.
        return ($ok);
      }
    } continue {
      $i--;
    }
    return ($ok);
}

################################################################################
# Return whether the variable with name $arg has a certain field named $name in
# its derived type.  If it has the field, the type of the entire variable
# (including the component field) is added to the local_var_info symbol table.

sub has_field {

    my($arg,$name) = @_;

    my($dotvar,$has_name_as_field);
    $has_name_as_field = 0;

    # Change fortran back to foo, if applicable.
    $arg =~ s/%/./g;
    $dotvar = "${arg}.${name}";

    my ($is_array_var,$is_declared_var,$arg_type,$arg_element_type,$arg_type_head_name);

    # First check if ARRAY variable

    ($is_array_var,$arg_type,$arg_element_type,$arg_type_head_name) = &is_declared_array_variable($arg); 

    if ($is_array_var) {
        if (! defined $tonto_type_info{$arg_type}) {
          &report_error("type \"$arg_type\" has not been defined in \"$typesfile\".");
        }
        # Add the type of variable $arg in case it isn't there because of a tail part
        %{$local_var_info{$arg}} = %{$tonto_type_info{$arg_type}};
        if (! defined $tonto_type_info{$arg_element_type}) {
          &report_error("type \"$arg_element_type\" has not been defined in \"$typesfile\".");
        }
        my $name_type = $tonto_type{$arg_element_type}{$name}{type_name};
        my $name_private = $tonto_type{$arg_element_type}{$name}{type_is_private};
        if (defined $name_type && ! $name_private) { # Does the array element have $name as a field?
            $has_name_as_field = 1;
            # Change $name_type if $arg is an array type
            if ($arg_type_head_name ne '') {
               $name_type = $arg_type_head_name . '{'. $name_type . '}';
            }
            if (! defined $tonto_type_info{$name_type}) {
              &report_error("type \"$name_type\" has not been defined in \"$typesfile\".");
            }
            %{$local_var_info{$dotvar}} = %{$tonto_type_info{$name_type}};
        }
        return ($has_name_as_field);
    }

    #If not an array variable, check if NON-ARRAY variable

    ($is_declared_var,$arg_type) = &is_declared_variable($arg);

    if ($is_declared_var) {
        if (! defined $tonto_type_info{$arg_type}) {
          &report_error("type \"$arg_type\" has not been defined in \"$typesfile\".");
        }
        my $name_type = $tonto_type{$arg_type}{$name}{type_name};
        my $name_private;
        if ($arg_type eq $module_name) { 
           $name_private = 0;  # no private names in module of same type name
        } else {
           $name_private = $tonto_type{$arg_type}{$name}{type_is_private};
        }
        if (defined $name_type && ! $name_private) { # Does $arg have $name as a field?
            $has_name_as_field = 1;
            if (! defined $tonto_type_info{$name_type}) {
              &report_error("type \"$name_type\" has not been defined in \"$typesfile\".");
            }
            %{$local_var_info{$dotvar}} = %{$tonto_type_info{$name_type}};
        }
        return ($has_name_as_field);
    }

    return ($has_name_as_field);
}

################################################################################
# Returns whether the preprocessor has previously determined that the argument
# is a declared variable, ARRAY OR SCALAR. $arg_type is set to the type of the
# variable.  WARNING: You must check before that it is NOT a declared array
# variable using the &is_declared_array_variable routine below.  That is because
# of the removal of the string part which has the effect of stripping any array
# tail part. Then, for array arguments $arg, the routine will return TRUE, but
# the $arg_type will be wrong and refer to the type of the $arg array head.

sub is_declared_variable {

    my($arg) = @_;

    my($is_declared_var,$arg_type);
    $is_declared_var = 0;
    $arg_type = "unknown";

    # Just in case the variable is a string type with subscript
    my ($arg_head,$arg_tail) = &split_by_last_brackets($arg);

    # Now see if we know about its type info
    if (defined $local_var_info{$arg_head}{type_name}) {
        $is_declared_var = 1;
        $arg_type = $local_var_info{$arg_head}{type_name};
    }
    return ($is_declared_var,$arg_type);
}

################################################################################
# Returns whether the preprocessor has previously determined that variable $arg
# is a declared ARRAY variable.  $arg_type is set to the type of variable $arg.
# $arg_element_type is the type of the scalar element part of the array.
# $arg_type_head_name is the type head name of the type of variable $arg.
# It could be blank in the case that $arg_type is scalar.

sub is_declared_array_variable {

    my($arg) = @_;

    my($is_array_var,$arg_type,$arg_element_type,$arg_type_head_name);
    $is_array_var = 0;
    $arg_type = "unknown";
    $arg_element_type = "unknown";

    # Separate out the head of the array from the element part, if any
    my ($arg_head,$arg_tail) = &split_by_last_brackets($arg);

    # Now see if we know about its type info
    my ($arg_head_type);
    if (defined $local_var_info{$arg_head}{type_name}  
           &&   $local_var_info{$arg_head}{is_array_type}) {
        $is_array_var = 1;
        $arg_head_type    = $local_var_info{$arg_head}{type_name};
        $arg_element_type = $local_var_info{$arg_head}{type_arg}[1];
        $arg_type_head_name = &array_var_type_head_name($arg_tail);
        if    ($arg_tail eq '') {
           $arg_type = $arg_head_type;    # No tail, type is same as $arg_head
        }
        elsif ($arg_type_head_name eq '') {
           $arg_type = $arg_element_type; # Has tail, but is a zero slice
        } else {
           $arg_type = $arg_type_head_name . '{' . $arg_element_type . '}' ;
        }
    }
    return ($is_array_var,$arg_type,$arg_element_type,$arg_type_head_name);
}

################################################################################
# Given the $tail_part of an array, e.g. "1,:,b", work out the $type_head_name
# of the array variable. If the array slice dimension is zero, the
# $type_head_name is blank.  $tail can also be blank.
sub array_var_type_head_name {
    my($tail_part) = @_;
    my($type_head_name,$slice_dim);
    $slice_dim = &slice_dimension($tail_part); # zero means full array !!!!
    if ($slice_dim == 0) {
       $type_head_name = '';
    } else {
       $type_head_name = $tonto_intrinsic_array_type_names[$slice_dim];
    }
    return ($type_head_name);
}


################################################################################
# Return the fortran slice dimension of $tail, i.e. the slice dimension for
# a(:,b,1) is 2 if b if of type VEC{INT}.
sub slice_dimension {
   my ($tail) = @_;
   my ($index,$cnt);
   # Just add up all the array args or explicit slices
   $cnt = 0;
   while ($tail =~ /(.+?)(?:,|\Z)/g) {
      $index = '';
      if (defined $1) { $index = $1; }
      if    ($index =~ ':')                                    { $cnt++; }
      elsif (defined $local_var_info{$index}{type_name} &&
             $local_var_info{$index}{type_name} =~ '^VEC{INT') { $cnt++; }
   }
   return ($cnt);
}

################################################################################
# Return the type of the argument, otherwise return "unknown". The argument may
# be in fortran form i.e. with % symbol type field separators. If so, the %
# symbols are converted to dots, since the routine works internally with dots.

sub type_of_this {

  my $arg = $_[0];

  my ($tmp,@tmp,$i,$x,$y,$left,$middle,$right,$is_a_var,$arg_type);
  my ($lefttype,$middletype,$righttype);

  # convert any % symbols to dots.
  $arg =~ s'%'.'go;

  # remove spaces.
  $arg =~ s'[ ]''go;

  # remove outside brackets.
  while ($arg =~ '^[(](.*)[)]$') {$arg = $1}

  # Check if it is in the local_var_info table
  $tmp = $local_var_info{$arg}{type_name};
  if (defined $tmp) { return ($tmp); }

  # Dylans Comment: I dont know why up to <<<<<<< EOF is needed. If the dots are
  # processed from left to right they should always appear in the
  # $local_var_info table. Also, the foo_type_of_this is identical to this
  # routine except that dots are used. Perhaps it is worth changing the % signs
  # to dots once and for all at the start of the routine and just have a
  # type_of_this routine (with the optional change if it is really needed).

  # Does it contain derived types?
  # A call to &has_field will add each component to the local hash table if not
  # there already.
  if ($arg =~ /(.*)[.](.*?)$/) {
    $i = 0;
    while ($i < length $arg) {
      $y = substr $arg,$i,1;
      if ($y eq '.') {
        $left = substr $arg,0,$i;
        $right = substr $arg,$i+1;
        &has_field($left,$right);
      }
      $i++;
    }
  }

  # we might be lucky with it being an array.
  ($is_a_var,$arg_type) = &is_declared_array_variable($arg);
  if ($is_a_var) { return ($arg_type); }

  # we might be lucky with it being a single variable.
  ($is_a_var,$arg_type) = &is_declared_variable($arg);
  if ($is_a_var) { return ($arg_type); }

  # a real literal constant.
  if ($arg =~ '^([+-])?\d*[.](\d+)?') {
    return ('REAL');
  }

  # a real constant.
  if ($arg =~ '([+-])?(ONE)|(TWO)|(THREE)|(FOUR)|(FIVE)|(TEN)|(ZERO)') {
    return ('REAL');
  }

  # an integer constant.
  if ($arg =~ '^([+-1234567890]+)$') {
    return ('INT');
  }

  # a string literal constant.
  if ($arg =~ /("[^"]*")|('[^']*')/) {
    return ('STR');
  }

  # perhaps it is a function we know about.
  if ($arg =~ '^(\w+)_[(]([\w.]+)(.*)') {
  # is above foolproof?
    # maybe do something more fancy with $2 later - recursive call to
    # fortran_type_of_this?

    if (defined $local_var_info{$2}{type_name}) {
      if (defined $function_res_type{"$local_var_info{$2}{type_name}_$1"}) {
        return ($function_res_type{"$local_var_info{$2}{type_name}_$1"});
      }
    }
  }

  # size intrinsic returns an INT.
  if ($arg =~ '^size[(](.*)[)]$') {
    return ('INT');
  }

  # deal with selfless functions; type of the function is the result type
  foreach $i (keys %function_res_type) {
    if ("${module_full_name}_${arg}" eq $i) {
      return ($function_res_type{$i});
    }
  }

  # min/max function.
  if ($arg =~ '^max[(](.*)[)]$' || $arg =~ '^min[(](.*)[)]$') {
    @tmp = split /[,]+/,$1;
    undef $tmp;
    THAT : foreach my $i (@tmp) {
      $x = &type_of_this($i);
      if (! defined $tmp) { $tmp = $x; }
      if ($tmp ne $x)     { $tmp = "unknown"; last THAT; }
    }
    return ($tmp);
  }

  # is it a function call?
  # This should get combined with function call stuff above.
  if ($arg =~ '^(.*?)[(](.*)[)]$' && &has_matching_brackets($arg)) {
    my $tmp = $1;
    my $i = $2;
    if (defined $tmp && $tmp =~ '\w$') {
      my $typ = &type_of_this($i);
      $tmp =~ s/_$//g;
      if (defined $function_res_type{"${typ}_$tmp"}) {
        return ($function_res_type{"${typ}_$tmp"});
      }
      if (defined $function_res_type{"${typ}_${tmp}_"}) {
        return ($function_res_type{"${typ}_${tmp}_"});
      }
    }
    if (defined $tmp && $tmp =~ '\w$') {
      return 'unknown';
    }
  }

  # lets get the type of things in brackets.
  if ($arg =~ '^\(' && &has_matching_brackets($arg)) {
    undef $lefttype;
    undef $middletype;
    undef $righttype;

    ($left,$middle,$right) = &split_by_first_brackets($arg);

    # This first bit is for arrays.
    if (defined $left && $left =~ '\w$') {
      $lefttype = &type_of_this($left . '(' . $middle . ')');
      undef $middletype;
      if (defined $right  && $right  ne '') { $righttype = &type_of_this($right);}

    } else {
      if (defined $left   && $left   ne '') { $lefttype   = &type_of_this($left);}
      if (defined $middle && $middle ne '') { $middletype = &type_of_this($middle);}
      if (defined $right  && $right  ne '') { $righttype  = &type_of_this($right);}
    }

    # Now check if all the types are the same
    undef $tmp; 
    if (! defined $tmp) { $tmp = $lefttype; }
    if (! defined $tmp) { $tmp = $middletype; }
    if (! defined $tmp) { $tmp = $righttype; }  # tmp set to 1st defined thing

    if (defined $tmp) { # compare $tmp with the others
      if (defined $lefttype)   {if ($lefttype   ne $tmp) {return 'unknown'}}
      if (defined $middletype) {if ($middletype ne $tmp) {return 'unknown'}}
      if (defined $righttype)  {if ($righttype  ne $tmp) {return 'unknown'}}
      return $tmp;
    }
  }

  # maybe a simple combination of variables, all of the same type.
  if ($arg =~ /[=\+\-\*\/]+/) {
     $left  = $PREMATCH;
     $right = $POSTMATCH;
     if ($left ne '') {
       $x = &type_of_this($left);
     }
     if ($right ne '') {
       $y = &type_of_this($right);
     }
     if ($left ne '' && $right ne '' ) {
       if ($x ne $y) { return("unknown"); }
       else          { return($x); }
     } elsif ($left ne '') {
       return ($x);
     } elsif ($right ne '') {
       return ($y);
     }
  }

  return ('unknown');
}

################################################################################
# Analyse a routine name and store all the routine attributes ...

sub analyse_rout_name {

    my ($X) = @_;

    my ($name,$function,$indent,$args,$result,$result_arg,$attr);

    # This checks if the current routine is an interface within an unused/used routine
    my ($within_unused) = $#scope>2 && $do_usd && 
            ! defined $usd{$routine{$current_rout_name}{short_name}};

    # Check for common typo
    if ($X =~ / :: /) {
        &report_error("use triple dot for routine attributes, \"$X\".");
    }

    # Parse the subroutine or function line
    $X =~ m/^(\s*)                        # space 
            (\w+)                         # routine name
            (?:\(([\s\w,]+)\))? \s*       # routine arguments  
            (?:result\s*\(([\s\w]+)\))?   # function result 
            (?:\s*:::\s*(.*?))?\s*$       # routine attributes
           /x;
    if (defined $1) { $indent = $1;  } 
    else            { $indent = ''; }
    if (defined $2) { $name = $2} 
    else            { &report_error("no routine name."); }
    if (defined $3) { $args = $3; } 
    else            { $args = ''; }
    if (defined $4) { $result = $4; } 
    else            { $result = ''; }
    if (defined $5) { $attr = $5; } 
    else            { $attr = ''; }

    # Save the non-unique $short_name, set $current_rout_name
    my $short_name = $name;
    $current_rout_name = $name;

    # Save the result argument
    if ($result ne '') {
       $result_arg = $result;
       $result_arg =~ s/\(\s*(\w+)\s*\)/$1/;
    } else {
       $result_arg = '';
    }

    # If this is a template or unused routine, do the minimum and get out.
    my $is_unused = $do_usd && ! defined $usd{$short_name} && $#scope<=2;
    if ($attr =~ /^template/ || $is_unused || $within_unused) {
       $routine{$short_name}{template} = 1;  
       $routine{$short_name}{short_name} = $short_name;
       $routine{$short_name}{real_name}  = $short_name;
       push @rout_name_stack, $short_name;
       if ($is_unused && $pass==2) { print "skipped $short_name"; }
       return;
    }

    # Count the number of times the name is used
    if ($#scope<=2 && $attr !~ /^template/ && $attr !~ /inlined_by_foo/ ) { 
       $overload_count{$short_name}++; # This is reset every pass
       if ($pass==1) { $first_overload_count{$short_name}++; }
    }
    my $overloaded = (defined $overload_count{$short_name} &&
                              $overload_count{$short_name} > 1);

    # Set the "real name" (the name which IS overloaded with _n)
    # The "real name" is not correct until the second pass.
    my $real_name;
    if ($#scope > 2) { # Don't worry about routines within interfaces.
          $real_name = $short_name;
    } else {
       if (defined $first_overload_count{$short_name} &&
           defined $overload_count{$short_name} &&
           ($first_overload_count{$short_name}>1 || 
                  $overload_count{$short_name}>1)) {
          my $n = $overload_count{$short_name} - 1;
          $real_name = $short_name . "_" . $n;
       } else {
          $real_name = $name;
       }
    }

    $routine{$short_name}{short_name} = $short_name;
    $routine{$short_name}{real_name}  = $real_name;

    # Keep ensure statements, and put back later. We have to use the $short_name
    # for the first routine of an overloaded set because on the first pass, when
    # the ensure statement is stored, we don't yet know what the $real_name will 
    # be i.e. whether it will end in a _0.
    my $ensure = undef;
    if ($do_tidy) {
       if ($overloaded) { $ensure = $routine{$real_name}{ensure_statements}; }
       else             { $ensure = $routine{$short_name}{ensure_statements}; }
    }

#print "-------------";
#print "short=$short_name";
#print "real =$real_name";
#print "ovl? =",$overloaded;
#print "cnt  =",$overload_count{$name};
#print "ensure:$ensure";
#print "---done------";

    # From now on $name is the unique $real_name
    $name = $real_name;

    # Clear the routine attributes hash
    undef %{$routine{$name}}; 

    # Put back only this old stuff
    $routine{$name}{short_name} = $short_name;
    $routine{$name}{real_name} = $real_name;
    $routine{$name}{ensure_statements} = $ensure;

    # Add to the routine name stack. Needed for routines within interface blocks
    # within routine declaration parts. Set $current_rout_name to the unique $real_name
    $current_rout_name = $name;
    push @rout_name_stack, $name;

    $n_define_type = 0;
    @old_define_type = undef;
    @new_define_type = undef;
    @old_expand_type = undef;
    @new_expand_type = undef;

    # Store the indent
    $routine{$name}{indent} = $indent; 

    # Is it a function?
    if ($result ne '') {
      $routine{$name}{function} = 1;
      $routine{$name}{function_result} = $result_arg;
      $routine{$short_name}{function} = 1;
      $routine{$short_name}{function_result} = $result_arg;
    }

    # Start looking for the first active line of code
    $routine{$name}{first_active_line} = 0; 

    # Analyse routine attributes (after the ::: specifier)
    if ($attr ne '') {
      $attr =~ s/(get_from.*)[)]\s*,/$1,/;        # remove last bracket
      $attr =~ s/(get_from.*)[)]\s*$/$1/;         # remove last bracket
#print "attr   =$attr";
      my @tmp = split(/\s*,?\s+/,$attr);
#print "tmp    =@tmp";
      foreach (@tmp) {
        /^leaky/            && do { $routine{$name}{leaky}=1;            next}; # has a memeory leak
        /^private/          && do { $routine{$name}{private}=1;          next}; # generic interface made private
        /^public/           && do { $routine{$name}{public}=1;           next}; # specific interface made public
        /^selfless/         && do { $routine{$name}{selfless}=1;         next}; # self is not first argument
        /^functional/       && do { $routine{$name}{functional}=1;       next}; # first arg is function, return REAL
        /^routinal/         && do { $routine{$name}{routinal}=1;         next}; # first arg is function
        /^pure/             && do { $routine{$name}{pure}=1;             next}; # pure routine
        /^always_pure/      && do { $routine{$name}{always_pure}=1;             # must always be pure (no macro override)
                                    $routine{$name}{pure}=1;             next};
        /^elemental/        && do { $routine{$name}{elemental}=1;               # elemental routine
                                    $routine{$name}{pure}=1;             next};
        /^always_elemental/ && do { $routine{$name}{always_elemental}=1;        # must always be elemental
                                    $routine{$name}{pure}=1;             next};
        /^recursive/        && do { $routine{$name}{recursive}=1;        next}; # recursive
        /^get_from/         && do { /[(]\s*([^ ]*)/; # remove first brackets
                                    $routine{$name}{inherited}=1;               # inherited routine
                                    my $parent_module=$1;                       # where inherited from
                                    if ($parent_module=~/([^ ]*):([^ ,]*)/) {
                                       $routine{$name}{parent_module} =$1;      # where inherited from
                                       $routine{$name}{parent_routine}=$2;      # new routine name
                                    } else {
                                       $routine{$name}{parent_module}=$parent_module;   
                                       $routine{parent_routine}=undef;          # no new routine name
                                    }
                                    $inherit_string = "";                       # the inherit match string
#print "---inherit---";
#print "parent=$1";
#print "-------------";
                                                                         next}; # 
        /^template/         && do { $routine{$name}{template}=1;         next}; # will be inherited, treated above
        /^inlined_by_foo/   && do { $routine{$name}{inlined_by_foo}=1;   next}; # will manually inlined
#       /^alias/            && do { $n_define_type++;
#                                   my $n = $n_define_type;
#                                   $_ =~ /^[^(]*[(]\s*([\w{,}.]+)\s*=>\s*([\w{,}.]+)\s*[)]/;
#                                   $old_define_type[$n] = $1;
#                                   $new_define_type[$n] = $2;
#                                                                        next};
        '=>'                && do { $n_define_type++;                           # A=>B aliases
                                    my $n = $n_define_type;
                                    $_ =~ /([^ ]*)\s*=>\s*([^ ]*)/;
                                    my $old = $1;
                                    my $new = $2;
                                    $old_define_type[$n] = $old;
                                    $new_define_type[$n] = $new;
                                    my %info; my @type_arg; 
                                    %info = &analyse_type_name($old,0);
                                    @type_arg = @{$info{type_arg}};
                                    $old_expand_type[$n] = [ &get_all_type_arguments(\@type_arg) ];
                                    %info = &analyse_type_name($new,0);
                                    @type_arg = @{$info{type_arg}};
                                    $new_expand_type[$n] = [ &get_all_type_arguments(\@type_arg) ];
#print "---alias-----";
#print "X      =$X";
#print "_      =$_";
#print "old    =$old";
#print "new    =$new";
#print "-------------";
                                                                         next};
        &report_error("unexpected routine attribute, \"$_\".");
      }
    }

    # Routines which are in interfaces are selfless.
    if ($#scope > 2) { $routine{$name}{selfless} = 1; }   

    # Store the routine arguments

    if (defined $routine{$name}{selfless}) {
          $args = "(" . $args . ")" ;
    } else {
       if ($args ne '') {             # This routine has arguments ....
          $args = "(self,$args)";     # insert self as first argument
       } else {                       # This routine has no arguments
          $args = "(self)";           # insert self as only arg
       }
    }
    $routine{$name}{arg_string} = $args;

    # Analyse the routine arguments

    my $narg = 0;
    while ($args =~ /(\w+)/g) {
       $narg++;
       $routine{$name}{arglist}{$1} = $narg;
       $routine{$name}{argarray}[$narg] = $1;
    }
    if ($result_arg ne '') {          # Add function result as the result argument
       $narg++;
       $routine{$name}{arglist}{$result_arg} = $narg;
    }
    $routine{$name}{narg} = $narg;

    # Create and destroy routines automatically get the leaky attribute.
    if ($name =~ m'(?:create)|(?:destroy)') { $routine{$name}{leaky} = 1; }
  
    # Set whether generic interface is private (default is public)
    # This is only recognised for the first of a set of overloaded routines.
    if (defined $routine{$name}{private}) {
       if (defined $routine{$short_name}{generic_access} && 
                   $routine{$short_name}{generic_access} eq "public") {
           &report_error("A previously overloaded routine with the same name had public access.");
       } 
       $routine{$short_name}{generic_access} = "private"; 
    } elsif (! defined $routine{$name}{private}) {
       $routine{$short_name}{generic_access} = "public"; 
    }
  
    # Set whether specific name is public (default is private)
    if (defined $routine{$name}{public}) {    # Makes the specific interface public
       $routine{$name}{specific_access} = "public";
    } else {
       $routine{$name}{specific_access} = "private";
    } 

    # Get the type arguments, if any ...

    @inherited_type_arg    = undef;
    $n_inherited_type_args = 0;
    if ($routine{$name}{inherited}) {
       my $type_name = $routine{$name}{parent_module};
       if ($type_name ne $module_name) { $used_modules{"$type_name (virtual)"} = 1; }
       my %info = &analyse_type_name($type_name,0);
       my @type_arg           = @{$info{type_arg}};
       @inherited_type_arg    = &get_all_type_arguments(\@type_arg);
       $n_inherited_type_args = $#inherited_type_arg;
       $current_type_name = undef;
    } 

    if ($do_routine_calls && $pass==2 && $#scope<=2) {
        print RCFILE "$short_name:";
    }

}

################################################################################
# Get the type arguments, if any ....

sub get_all_type_arguments {

   my $type_arg_ref = shift;

   my @type_arg = @{$type_arg_ref};

   my ($n_type_arg_args,@type_arg_arg);
   my ($i,%info);

   # Check to see if each type arg does not have its own type args!
   # If so, add them to the list of type args. The order of this list is
   # critical because for inherited types the type substitution occurs in this
   # order. The order is depth first in nested curly brackets.
      for ($i=1;$i<=$#type_arg;$i++) {
         %info = &analyse_type_name($type_arg[$i],0);
         $n_type_arg_args = $info{n_type_args};
         @type_arg_arg    = @{$info{type_arg}};
         if ($n_type_arg_args>0) { # Type arg has arguments -- add parent and child args
            @type_arg_arg = &get_all_type_arguments(\@type_arg_arg);
            @type_arg = (0,                # 0-thargument not used
                         @type_arg[1..$i], # Keep previous arguments
                         @type_arg_arg[1..$#type_arg_arg], # Insert new
                         @type_arg[($i+1)..$#type_arg]);   # Not yet analysed ...
            $i += $#type_arg_arg;          # Skip the added arguments
         } else {                  # This does not, just add its parent
         }
      }

   return (@type_arg);

}

################################################################################
# Return TRUE if a variable with name $name is included in the routine argument
# list of the current routine.
sub routine_has_arg {
    my $name = $_[0];
    my($arg,$has);
    $has = 0;
    foreach $arg (keys %{$routine{$current_rout_name}{arglist}}) {
       next if ($arg ne $name);
       $has = 1;
       last;
    }
    return ($has);
}

################################################################################
# Bracket splitting routines .....
################################################################################

################################################################################
# This routine breaks up the line into what's before the LAST set of round
# brackets, and what's in the brackets.  For example,
# &split_by_last_brackets("if ((a) + b(c(d)) == 1) (hi)") returns
# "if ((a) + b(c(d)) == 1) " and "hi".

sub split_by_last_brackets {

   my($string) = @_;

   my ($head,$tail);
   $head = $string;
   $tail = "";
   if ($string =~ '(.*)([(].*?[)])\Z') {;         # Not greedy match
       $head = $1;
       $tail = $2;
       while (! &has_matching_brackets($tail)) {  # In here if it didn't match
          $head =~ '(.*)([(].*)\Z';               # Greedy first part
          $head = $1;
          $tail = $2 . $tail;                     # Grow tail backwards
       }
       $tail =~ '[(](.*)[)]';
       $tail = $1;
   }
   ($head,$tail);
}

################################################################################
# This routine breaks up the line into what's before the LAST set of round
# brackets, and what's in the brackets.  For example,
# &split_by_last_brackets("if ((a) + b(c(d)) == 1) (hi)") returns
# "if ((a) + b(c(d)) == 1) " and "hi".

sub split_by_last_curly_brackets {

   my($string) = @_;

   my ($head,$tail);
   $head = $string;
   $tail = "";
   if ($string =~ '(.*)([{].*?[}])\Z') {;
       $head = $1;
       $tail = $2;
       while (! &has_matching_curly_brackets($tail)) {
          $head =~ '(.*)([{].*)\Z';
          $head = $1;
          $tail = $2 . $tail;
       }
       $tail =~ '[{](.*)[}]';
       $tail = $1;
   }
   ($head,$tail);
}

#################################################################################
## This routine breaks up the line into what's before the first set of 
## brackets, what's in the brackets, and what's after the brackets.
## For example,
## &split_by_first_brackets("if ((a) + b(c(d)) == 1) (hi)") returns
## "if ", "(a) + b(c(d)) == 1", and " (hi)".
#
#sub split_by_first_brackets {
#
#  my ($the_string,$left_string,$middle_string,$right_string);
#  my ($left,$right,$this_string,$rest_of_string,$length_of_rest,$n);
#  $the_string = $_[0];
#
#  $left_string = "";
#  $middle_string = $the_string;
#  $right_string = "";
#  $the_string =~ '(.*?)([{].*)';
#  $left_string = $1; # what's left of the "("
#  $rest_of_string = $2; # what's right of the "("
#  $left = length( $left_string ) + 1; # position of the "("
#  $length_of_rest = length($rest_of_string);
#  LOOP : for ( $n = 1; $n <= $length_of_rest; $n++) {
#    $rest_of_string =~ /^(.{\Q$n\E})/;
#    $this_string = $1;
#    if (&has_matching_brackets($this_string)) {
#      $this_string =~ '[{](.*)[}]';
#      $middle_string = $1; # what's between the "(" and ")".
#      last LOOP;
#    }
#  }
#  $right = $left + length( $middle_string ) + 1; # position of the ")"
#  $the_string =~ /.\Q$right\E(.*)/;
#  $right_string = $1; # what's right of the ")"
#
#  ($left_string,$middle_string,$right_string)
#}

################################################################################
# This routine breaks up the line into what's before the first set of 
# brackets, what's in the brackets, and what's after the brackets.
# For example,
# &split_by_first_brackets("if ((a) + b(c(d)) == 1) (hi)") returns
# "if ", "(a) + b(c(d)) == 1", and " (hi)".

sub split_by_first_brackets {

  my ($the_string,$left_string,$middle_string,$right_string);
  my ($left,$right,$this_string,$rest_of_string,$length_of_rest,$found,$n);

  $the_string = $_[0];
  $the_string =~ m'([(].*)'o;
  if (! defined $1 || $1 eq '') {
     $left_string    = $the_string;
     $middle_string  = '';
     $right_string   = '';
  } else {
     $left_string    = $PREMATCH; # what's left of the "("
     $rest_of_string = $1;        # what's right of the "("
     $length_of_rest = length($rest_of_string);
     $found = 0;
     LOOP : for ( $n = 1; $n <= $length_of_rest; $n++) {
       $rest_of_string =~ /^(.{\Q$n\E})/;
       $this_string = $1;
       if (&has_matching_brackets($this_string)) {
         $this_string =~ '[(](.*)[)]';
         $middle_string = $1;     # what's between the "(" and ")".
         $found = 1;
         last LOOP;
       }
     }
     if (! $found ) { &report_error("unmatching curly brackets."); }
     $right = length($left_string) 
            + length($middle_string) 
            + 2;                  # position after ")"
     $the_string =~ /.{\Q$right\E}(.*)/;
     $right_string = $1;          # What's right of the ")"
  }

  return ($left_string,$middle_string,$right_string)
}

sub has_matching_brackets {
# This routine returns whether the number of "(" equals the number of ")".
  (($_[0] =~ tr/[(]//) == ($_[0] =~ tr/[)]//));
}

sub has_matching_curly_brackets {
# This routine returns whether the number of "(" equals the number of ")".
  (($_[0] =~ tr/[{]//) == ($_[0] =~ tr/[}]//));
}

################################################################################
# This routine breaks up the line into what's before the first set of *curly*
# brackets, what's in the brackets, and what's after the brackets.
# For example,
# &split_by_first_brackets("if {{a} + b{c{d}} == 1} {hi}") returns
# "if ", "{a} + b{c{d}} == 1", and " {hi}".
# If the opening curly bracket is not there, the whole string as the left
# string. If an opening curly bracket is found but no closing curly bracket, it
# is an error.

sub split_by_first_curly_brackets {

  my ($the_string,$left_string,$middle_string,$right_string);
  my ($left,$right,$this_string,$rest_of_string,$length_of_rest,$found,$n);

  $the_string = $_[0];
  $the_string =~ /([{].*)/;
  if (! defined $1 || $1 eq '') {
     $left_string    = $the_string;
     $middle_string  = '';
     $right_string   = '';
  } else {
     $left_string    = $PREMATCH; # what's left of the "{"
     $rest_of_string = $1;        # what's right of the "{"
     $length_of_rest = length($rest_of_string);
     $found = 0;
     LOOP : for ( $n = 1; $n <= $length_of_rest; $n++) {
       $rest_of_string =~ /^(.{\Q$n\E})/;
       $this_string = $1;
       if (&has_matching_curly_brackets($this_string)) {
         $this_string =~ '[{](.*)[}]';
         $middle_string = $1;     # what's between the "{" and "}".
         $found = 1;
         last LOOP;
       }
     }
     if (! $found ) { &report_error("unmatching curly brackets."); }
     $right = length($left_string) 
            + length($middle_string) 
            + 2;                  # position after "}"
     $the_string =~ /.{\Q$right\E}(.*)/;
     $right_string = $1;          # What's right of the "}"
  }

  return ($left_string,$middle_string,$right_string)
}
################################################################################
# Tidy the .foo file
################################################################################

################################################################################
# Open the tidy file.
sub tidy_start {
  -f $tidyfile && unlink($tidyfile);
  open(TIDYFILE,">".$tidyfile);
}

################################################################################
# End the tidy stuff, and close the tidy file.
sub tidy_end {
  close TIDYFILE;
}

################################################################################
# Return TRUE if the routine with name $name calls the routine called $call
sub routine_calls_this_routine {
    my $name = $_[0];
    my $call = $_[1];

    if (! defined $routine_calls{$name}) { return(0); }
    if (! defined @{$routine_calls{$name}}) { return(0); }

    my($arg,$has);
    $has = 0;

    foreach $arg (@{$routine_calls{$name}}) {
       next if ($arg ne $call);
       $has = 1;
       last;
    }
    return ($has);
}
