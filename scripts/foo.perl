## foo.perl
## ! $Id$

use English;            # Get rid of horrible Perl short forms

$, = ' ';		# set output field separator
$\ = "\n";		# set output record separator

$inp = ' ';             # current processed input line

$ExitValue = 0;

## -----------------------------------------------------------------------------
## Define the .foo file and corresponding .f90 file       
## -----------------------------------------------------------------------------

@ARGV==3  or die "Must supply 3 file names; input, output and interface files.";

$foofile = $ARGV[0];   # This is the .foo file to work on
$f90file = $ARGV[1];   # This is the .f90 file produced
$intfile = $ARGV[2];   # This is the .int file produced

$typfile = 'foofiles/types.foo'; # Should be an argument?

open(FOOFILE,$foofile) or die "$FOOFILE does not exist,";

system("rm -f $f90file");
open(F90FILE,">".$f90file);

## -----------------------------------------------------------------------------
## Set up the components of known vector types            
## -----------------------------------------------------------------------------

%component_type = (     # Components of the vector types
    'VEC'           => 'DBL',
    'IVEC'          => 'INT',
    'CVEC'          => 'CDBL',
    'BINVEC'        => 'BIN',
    'STRVEC'        => 'BIN',
    'VECVEC'        => 'VEC_',
    'IVECVEC'       => 'IVEC_',
    'MATVEC'        => 'MAT_',
    'MAT3VEC'       => 'MAT3_',
    'SHELLVEC'      => 'SHELL',
    'SHELLPAIRVEC'  => 'SHELLPAIR',
    'BASISVEC'      => 'BASIS',
    'ATOMVEC'       => 'ATOM',
    'REFLECTIONVEC' => 'REFLECTION',
    'IRREPVEC'      => 'IRREP',
    'MAT'           => 'DBL',
    'IMAT'          => 'INT',
    'CMAT'          => 'CDBL',
    'MAT3'          => 'DBL',
    'IMAT3'         => 'INT',
    'CMAT3'         => 'CDBL',
    'MAT4'          => 'DBL',
    'IMAT4'         => 'INT',
    'CMAT4'         => 'CDBL',
    'MAT5'          => 'DBL',
    'IMAT5'         => 'INT',
    'CMAT5'         => 'CDBL',
);

## -----------------------------------------------------------------------------
## Set up some substitutions which always apply
## -----------------------------------------------------------------------------

%subst = (          # Substitutions .................
    ' STR '     => ' STR(STR_SIZE) ',
    ' BSTR '    => ' STR(BSTR_SIZE) ',
    ' STR,'     => ' STR(STR_SIZE),',
    ' BSTR,'    => ' STR(BSTR_SIZE),',
    'VEC '      => 'VEC(:) ',
    'MAT '      => 'MAT(:,:) ',
    'MAT3 '     => 'MAT3(:,:,:) ',
    'MAT4 '     => 'MAT4(:,:,:,:) ',
    'MAT5 '     => 'MAT5(:,:,:,:,:) ',
    'VEC,'      => 'VEC(:),',
    'MAT,'      => 'MAT(:,:),',
    'MAT3,'     => 'MAT3(:,:,:),',
    'MAT4,'     => 'MAT4(:,:,:,:),',
    'MAT5,'     => 'MAT5(:,:,:,:,:),',
    'VEC\*'     => 'VEC(:), PTR',
    'MAT\*'     => 'MAT(:,:), PTR',
    'MAT3\*'    => 'MAT3(:,:,:), PTR',
    'MAT4\*'    => 'MAT4(:,:,:,:), PTR',
    'MAT5\*'    => 'MAT5(:,:,:,:,:), PTR',
);

## -----------------------------------------------------------------------------
## Set up the scoping units and patterns which detect them
## -----------------------------------------------------------------------------

$scopeunit = "";
$newscopeunitfound = 0;
$ns = 0;                # Scoping unit depth
$scope{$ns} = "name of the scoping unit";

%scopeunits = (         # Patterns which match the start of a block
   'program'          =>  '^ *program *[a-zA-Z]',
   'module'           =>  '^ *module *[a-zA-Z]',
   'interface'        =>  '^ *interface *([a-zA-Z]|$)',
   'select'           =>  '^ *select *[a-zA-Z]',
   'type'             =>  '^ *type *[a-zA-Z]',
   'do'               =>  '(^|:) *do *( [a-zA-Z]|$|[!;])',
   'forall'           =>  '^ *forall *[(]',
   'where'            =>  '^ *where *[(]', 
   'contains'         =>  '^ *contains',
   'if'               =>  '^ *if *[(][^;]*[)] *then(( *$)|( *[!;]))',
   'named-end'        =>  '^ *end *[a-z](?!.*[=(.])',
   'empty-end'        =>  '^ *end *(!|$)',
);

$first_active_line = 1;

## -----------------------------------------------------------------------------
## Define the type table arrays
## -----------------------------------------------------------------------------

$local_type{'variable name X'} = 'type of the variable X';

$global_type{'self'}   = 'The current module name' ;
$global_type{'tonto'}  = 'SYSTEM';
$global_type{'stdin'}  = 'TEXTFILE';
$global_type{'stdout'} = 'TEXTFILE';

$tonto_type{'type X'}{'field Y of X'} = 'type of the field Y of X';

## -----------------------------------------------------------------------------
## Argument lists of subroutines
## -----------------------------------------------------------------------------

$arglist{"argument name"} = "argument index";

## -----------------------------------------------------------------------------
## Analyse the types.foo file
## -----------------------------------------------------------------------------

open(TYPES,$typfile);

# Search for a type line

while (chop($X = <TYPES>)) {
    
    last if ($X =~ /^end/ );                        # End of types.foo
    next if ($X !~ /type +([a-zA-Z]\w*)_type\b/);   # Look for next type definition
    ($type_name = $X) =~ s/.*type +//s;             # Get the type name
    $type_name =~ s/_type\b.*//s;
    $type_name = uc($type_name);
    $tonto_type{$type_name}{"--exists--"} = 1;      # Create the hash table for this type

    while (chop($X = <TYPES>)) {                    # Analyse the type declaration line
        last if ($X =~ /^ +end/ );                  # End of types def
        next if ($X =~ /^ +!/ );                    # Comment 
        &analyse_types($X,$tonto_type{$type_name}) 
    }

    delete $tonto_type{$type_name}{"--exists--"};   # Delete this token
}

close(TYPES);

## -----------------------------------------------------------------------------
## Loop over the .foo file lines
## -----------------------------------------------------------------------------

$linenum = 0;
LINE: while (<FOOFILE>) {

    chop;	# strip record separator

    $inp = $_;  # Get the line
    $linenum = $linenum + 1;

    if ($inp =~ /^ *\S/ && $inp !~ /^ *[!#]/ ) {                     # if not blank ...

	####### Look for a new scoping unit ####################################


        foreach $key (keys %scopeunits) {
            $pattern = $scopeunits{$key};
	    if ($inp =~ $pattern) {
	        $ns = $ns + 1;
                $scopeunit = $key;
	        $scope{$ns} = $key; # Found a new scopeing unit
	        $newscopeunitfound = 1;
	        last;
	    }
        } 
	########################################### Found a NEW scope unit #####

	if ($newscopeunitfound) {

	    $newscopeunitfound = 0;

	    if ($scopeunit eq 'module') {               # Module ###############

                # Get the module name #

		$inp =~ /^[ ]*module ([A-Z][A-Z_0-9]*)\b/;           
		($long_module_name = $inp) =~ s/^[ ]*module //s;
		$long_module_name =~ /^([A-Z0-9]*)/;
		$module_name = $1;

                # Assign the self type

	        $global_type{'self'} = $module_name;                 
	    }
                                                       # Module interface ######
	    elsif ($scopeunit eq 'interface' && $scope{$ns - 1} eq 'module') {

		# Change the interface declaration#

		$inp =~ s/^[ ]*interface ([a-z]\w*)/   public $1_; interface $1_/;
		$name = $1;
	    }
                                                       # Type def ##############

            if ($scopeunit eq 'type' && $scope{$ns - 1} eq 'module') {

               $type_name = $inp;
               $type_name =~ s/.*type +//s;         # Get the type name
               $type_name =~ s/_type\b.*//s;
               $type_name = uc($type_name);
            }
                                                       # end found #############
	    elsif ($scopeunit eq 'empty-end' ) {

	        $ns = $ns - 1; $scopeunit = $scope{$ns};
	        if ($scopeunit eq 'contains') { $ns = $ns - 1; $scopeunit = $scope{$ns}; }

		if (($scopeunit eq 'subroutine' || $scopeunit eq 'function') && $ns <= 3) {

		    # end Module routine. need ns<=3 to eliminate interface routines

		    if ($pure == 1)     { $inp =~ s/end */end $scopeunit/; }
		    elsif ($leaky == 1) { $inp =~ s/end */UNSTACK end $scopeunit/; }
		    else                { $inp =~ s/end */CHECK end $scopeunit/; }

                    # Delete the local type table

                    undef %local_type;
                    $local_type{'variable name X'} = 'type of the variable X';
		}

		### Generic end scope unit

		else {
		                          $inp =~ s/end */end $scopeunit/; 
                }

	        $ns = $ns - 1; $scopeunit = $scope{$ns};

	        if ($ns < 0) {
		    print "FOO error: unmatched end at line $linenum of $foofile";
		    $ExitValue = 1;
                    last LINE;
	        }
            }
		                                  #  explicit end <scope> ######
	    elsif ($scopeunit eq 'named-end' ) {

	        $ns = $ns - 1; $scopeunit = $scope{$ns};
	        if ($scopeunit eq 'contains') { $ns = $ns - 1; $scopeunit = $scope{$ns}; }
	        $ns = $ns - 1; $scopeunit = $scope{$ns};

	        if ($ns < 0) {
		    print "FOO error: unmatched end at line $linenum of $foofile";
		    $ExitValue = 1;
                    last LINE;
	        }
            }
	}

	############################################### quick error check ######

	elsif (! defined $scopeunit) {
	    print "FOO error: unmatched end?, near line $linenum of $foofile";
	    $ExitValue = 1;
	    last LINE;
	}

	###################################### Within a program or module ######

	elsif ($scopeunit eq 'program' || $scopeunit eq 'module') {

	    # Analyse any module variable declaration lines

	    if ($inp =~ '[A-Z][A-Z0-9]*[^:]*::[ ]*' ) { 
               &analyse_types($inp,\%global_type); 
            }
	}

	###################################### Within a module interface #######

	elsif ($scopeunit eq 'interface' && $scope{$ns - 1} eq 'module') {

	    # Expecting a module procedure ###############

	    $inp =~ '([a-zA-Z]\w*)';

	    $pre  = $PREMATCH;
	    $name = $POSTMATCH;
	    $inp = "${pre}module procedure $1";
	    $cont = 1;

            while ($name =~ /([a-zA-Z]\w*)/g) {
		$rout = $1;
		$routine_int{$rout} = 1;
		if (length($inp) > 90 * $cont) {
		    $inp = $inp . ", &\n${pre}   " . $rout;
		    $cont = $cont + 1;
		}
                else {
	            $inp = $inp . ", " . $rout;
                }
            }

	}

	################################### Within a subroutine or function ####

	elsif ($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function') {

	    # Analyse any variable declaration lines

	    if ($inp =~ '[A-Z][A-Z0-9]*[^:]*::[ ]*' ) { &analyse_types($inp,\%local_type); }

	}

	################################## Within a function interface #########

	elsif ($scope{$ns} eq 'interface' || $ns == 0) {

            # Analyse the routine name

	    &analyse_rout_name($inp);

	    if ($is_function) { $inp = "${pre}${attr}function ${name}${args}";   }
	    else              { $inp = "${pre}${attr}subroutine ${name}${args}"; }
	}

	############################################# Within a contains ########

	elsif ($scope{$ns} eq 'contains') {

	    # Expecting a subroutine/function line 

	    &analyse_rout_name($inp);
	    &store_arglist($args_only);    # arguments

	    if ($is_private) {                              # Use head name
                $routine_pvt{$name} = "private";
            }
            else {
                $routine_pvt{$name} = "public";
            }

	    if (&overloaded($name)) {                       # Overloaded routine
		$routine_cnt{$name}++;
		$name = "$name" . "_" . "$routine_cnt{$name}" ;
	    }
	    else {
		$routine_cnt{$name} = 0;
	    }

	    if ($is_function) { 
	       if ($is_selfless) { $inp = "${pre}${attr}function ${name}${args}";   }
	       else              { $inp = "${pre}${attr}function ${name}${self}";   }
            }    
	    else              { 
	       if ($is_selfless) { $inp = "${pre}${attr}subroutine ${name}${args}"; }
	       else              { $inp = "${pre}${attr}subroutine ${name}${self}"; }
            }    
	    if ($is_functional == 0 && $is_routinal == 0 && $is_selfless == 0) {
                                $inp = "$inp; $module_name :: self"; }

	    $real_routine_name = $name;

	    $first_active_line = 0;    # first active line of code not found yet

            # Assign global variable types to local

            %local_type = %global_type
	}

	############################################### Within a type def ######

	elsif ($scope{$ns} eq 'type') {

	    # Analyse a module type declaration body

            if ($inp =~ '::' ) { 
               $tonto_type{$type_name}{"--exists--"} = 1;      # Create hash 
               &analyse_types($inp,$tonto_type{$type_name});
               delete $tonto_type{$type_name}{"--exists--"};   # Delete token
            }

	}

	################################# lines that contain a dot. ############
	if ($inp =~ '.[.].') {
	########################################################################
	######################## Change self "." expressions on all lines ######
	while ($inp =~         /((?:^|;|[)] ) *)[.]([a-zA-Z_]\w*)(.*)/  ||
               $inp =~ '((?:[(=+-/*<>,:]|\w ) *)[.]([a-zA-Z_]\w*)(.*)'     ) {
            $first = $1;
            $pre = $PREMATCH . $1;
            $rout = $2;
            $dotpost = $2 . $3;
            $fixedpost = $3;
            if ($fixedpost !~ s/^[(]/,/ )    { $fixedpost = ')' . $fixedpost; }
            $call = 'call ';
            if ($first =~ '^[(=+-/*<>,:\w]') { $call = ''; }
	    if (&self_field($rout))          { $inp = "${pre}self%${dotpost}"; }
	    else                             { $inp = "${pre}${call}${rout}_(self${fixedpost}"; }
	}
	########################################################################
	####################################### change variable "." expressions 
	while ($inp =~ '((?:^|;|[)] ) *)([a-zA-Z_][\w%]*(?:[(][\w%,:+-]*[)][\w%]*){0,4})[.]([a-zA-Z_]\w*)(.*)'   ||
	       $inp =~ '((?:[(=+-/*<>,:]|\w ) *)([a-zA-Z_][\w%]*(?:[(][\w%,:+-]*[)][\w%]*){0,4})[.]([a-zA-Z_]\w*)(.*)'   ||
	       $inp =~ '((?:[(=+-/*<>,:]|\w ) *)([\w%]*(?:[(](?: *[\w%]*(?:[(][\w%,:+-]*[)][\w%]*){0,4}[ ]*[+-/*<>]*){1,3}[)]){0,1})[.]([a-zA-Z_]\w*)(.*)' ) {
            $first = $1;
            $pre = $PREMATCH . $1;
            $arg = $2;
            $rout = $3;
            $post = $4;
            $fixedpost = $4;
            if ($fixedpost !~ s/^[(]/,/ )    { $fixedpost = ')' . $fixedpost; }
            $call = 'call ';
            if ($first =~ '^[(=+-/*<>,:\w]') { $call = ''; }
	    if (&has_field($arg, $rout))     { $inp = "${pre}${arg}%${rout}${post}"; }
	    else                             { $inp = "${pre}${call}${rout}_(${arg}${fixedpost}"; }
	}
	########################################################################
	}
	####################################  STACK, UNSTACK, and CHECK ########
	if ($first_active_line == 0 && 
            $inp =~ /^[ ]*[a-zA-Z]/ && 
            $inp !~ /::/            && 
            $inp !~ / function/     &&
	    $inp !~ / subroutine/   &&
	    $inp !~ / interface/    &&
	    $inp !~ / use /         &&
	    $pure == 0) {
	    $first_active_line = 1;
            $inp =~ s/^ */   STACK(\"$module_name:$real_routine_name\") /;
            undef %arglist;
            $arglist{"argument name"} = "argument index";
	}
	if ($inp =~ /[)] *return *(!|$)/ ) {
	    # found an "return" #######################
	    if ($pure == 1) { ; }
	    elsif ($leaky == 1) { $inp =~ s/[)] *return */) then; UNSTACK return; end if/; }
	    else                { $inp =~ s/[)] *return */) then; CHECK return; end if/; }
	}
	if ($inp =~ /(^|;) *return */ ) {
	    # found an "return" #######################
	    if ($pure == 1) { ; }
	    elsif ($leaky == 1) { $inp =~ s/return/UNSTACK return/; }
	    else                { $inp =~ s/return/CHECK return/; }
	}
	########################################################################

	# Change some TYPE declarations #########################

	if ($inp !~ /^[ ]*[uU][sS][eE][ ]+.*/s) { # don't substitute use line.
		foreach $pattern (keys %subst) {
		    $inp =~ s/$pattern/$subst{$pattern}/;
        	}
	}

        $inp =~ s/OPMAT[(]:,:[)]/OPMAT/;    # Remove OPMAT conversion ... this
        $inp =~ s/OPVEC[(]:[)]/OPVEC/;      # should be changed!

        if ($inp =~ '::') {
           $inp =~ s/\* *::/, PTR ::/;      # Add remaining PTR conversion
           $inp =~ s/\*, /, PTR,/;          # 
        }

                                            # Add NULL() statements for local PTR's
    ##  if ($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function' ||
    ##      $scope{$ns} eq 'module'     || $scope{$ns} eq 'program') {
    ##     if ($inp =~ /, PTR/ && $inp =~ '::' && &contains_arg($inp) == 0 ) 
    ##        { &add_nullify_stmt }
    ##  }
                                            # Add DEFAULT_NULL statements for type defs
        if ($scope{$ns} eq 'type') {
           if ($inp =~ /, PTR/ && $inp =~ '::' ) 
              { $inp = $inp . " DEFAULT_NULL" }
        }

        $inp =~ s{\[}{(/}g;              # brackets [ ] are array constructors
        $inp =~ s{]}{/)}g;
    }

    print F90FILE $inp;           # Print the processed line!

    ############################################################################
    ############################################################################
    ############################################################################
}

close(F90FILE);

## -------------------------------------------------------
## Dump the interface file
## -------------------------------------------------------

if (lc($long_module_name) ne '') {

    system("/bin/rm -f $intfile");
    open(INTFILE,">".$intfile);

    print INTFILE "   private";    # This is good programming
                                   # but breaks functionals
    print INTFILE "";

    foreach $rout (keys %routine_cnt) {
	$cnt = $routine_cnt{$rout};
	$pvt = $routine_pvt{$rout};
	print INTFILE "   $pvt ${rout}_; interface ${rout}_";
	print INTFILE "      module procedure ${rout}";
	for ($i = 1; $i <= $cnt; $i++) {
	print INTFILE "      module procedure ${rout}_$i";
	}
	print INTFILE "   end interface";
	print INTFILE "";
    }
    close INTFILE;
}

exit $ExitValue;

################################################################################

sub analyse_rout_name {

    local($inp) = @_;

    # Analyse routine attributes (in square brackets)

    $is_function = 0;
    if ($inp =~ / result[ ]*[(]/ )        { $is_function = 1; }
    $is_private = 0;
    if ($inp =~ s/ \[private]// )         { $is_private = 1; }
    $is_selfless = 0;
    if ($inp =~ s/ \[selfless]// )        { $is_selfless = 1; $is_private = 1}
    $is_functional = 0;
    if ($inp =~ s/ \[functional]// )      { $is_functional = 1; }
    $is_routinal = 0;
    if ($inp =~ s/ \[routinal]// )        { $is_routinal = 1; }
    $pure = 0;
    $attr = '';
    if ($inp =~ s/ \[pure]// )            { $attr = 'PURE ';             $pure = 1; }
    if ($inp =~ s/ \[always_pure]// )     { $attr = 'ALWAYS_PURE ';      $pure = 1; }
    if ($inp =~ s/ \[elemental]//)        { $attr = 'ELEMENTAL ';        $pure = 1; }
    if ($inp =~ s/ \[always_elemental]//) { $attr = 'ALWAYS_ELEMENTAL '; $pure = 1; }
    if ($inp =~ s/ \[recursive]// )       { $attr = "${attr}recursive "; }
    $leaky = 0;
    if ($inp =~ s/ \[leaky]// )           { $leaky = 1; }

    # Analyse the routine name

    $inp =~ /([a-zA-Z]\w*)/;
    $pre  = $PREMATCH;                    # preceding string for the routine
    $name = $1;                           # routine name
    $args = $POSTMATCH;
    $args_only = $POSTMATCH;
    $args_only =~ s/ *$//;
    if ($args =~ /^[^ (]* *[(]/) {        # this routine has arguments ....
	$args = '(' . $POSTMATCH;         # routine arguments, including ( character + rest of line
	$self = "(self,$POSTMATCH";       # insert self as first argument
    }
    else {                                # this routine has no arguments
	$self = "(self)$args";            # insert self as only arg
    }
    if ($name =~ /create/ || $name =~ /destroy/) { $leaky = 1; }

    # Add the definition to the scope arrays

    if ($is_function) {                   # must be function
	$ns = $ns + 1;
        $scopeunit = 'function';
	$scope{$ns} = 'function';
    }
    else {                                # must be subroutine
	$ns = $ns + 1;
        $scopeunit = 'subroutine';
	$scope{$ns} = 'subroutine';
    }
}

sub store_arglist {
    local($args) = @_;

    $narg = 0;
    while ($args =~ /(\w+)/g) {
       $narg++;
       $arglist{$1} = $narg;
    }
}

sub contains_arg {
    local($name) = @_;
    $has = 0;
    foreach $arg (keys %arglist) { 
       if ($name =~ /[:, ]${arg}(,| *$)/) {
          $has = 1; 
          last;
       }
    }
    ($has);
}

sub add_nullify_stmt {

    if ($inp =~ /::[ ]*/) {

        $dec = $POSTMATCH;

        # Look for the declared variables, repeatedly

        while ($dec =~ /([a-zA-Z]\w*)/g) {

           $var = $1;
           if (&contains_arg($var) == 0) { 
              $inp =~ s/$var/$var=>NULL()/;
           }
           else {
              print 'FOO error: A routine argument and local variables have been declared';
              print "           on the same line $linenum of $foofile";
              $ExitValue = 1;
              last LINE;
           }
        }
    }
}

sub overloaded {
    local($name) = @_;
    $over = 0;
    if (defined $routine_cnt{$name}) { $over = 1; }
    ($over);
}

sub explicitly_overloaded {
    local($name) = @_;
    $over = 0;
    if (defined $routine_int{$name}) { $over = 1; }
    ($over);
}

sub self_field {
    local($name) = @_;
    $is_self_field = 0;
    if (defined $tonto_type{$module_name}{$name}) {
        $is_self_field = 1;
    }
    # Add this variable to the var type table ...
    &has_field('self', $name);
    ($is_self_field);
}

sub has_field {
    local($arg, $name) = @_;
    $has_name_as_field = 0;
    if (&is_array_var($arg)==1) {
        if (defined $tonto_type{$arg_type}{$name} ) { 
	    $has_name_as_field = 1;
	    $dotvar = "${arg}%${name}";
	    $local_type{$dotvar} = $tonto_type{$arg_type}{$name};
	}
	return ($has_name_as_field);
    }
    if (&is_var($arg)==1) {
	if (defined $tonto_type{$arg_type}{$name}) { 
	   $has_name_as_field = 1;
	   $dotvar = "${arg}%${name}";
	   $local_type{$dotvar} = $tonto_type{$arg_type}{$name};
	}
	return ($has_name_as_field);
    }
    ($has_name_as_field);
}

sub print_types {
    local($type_of) = @_;
    print '----types------';
    foreach $name (keys %{$type_of}) {
	print 'name=', $name, 'type=', $type_of->{$name};
    }
    print '---------------';
}

sub is_var {
    local($arg) = @_;
    $is_declared_var = 0;
    $arg_type = "unknown";
    if (defined $local_type{$arg}) {
	$arg_type = $local_type{$arg};
	$is_declared_var = 1;
    }
    ($is_declared_var);
}

sub is_array_var {
    local($arg) = @_;
    $is_declared_array_var = 0;
    $arg_type = "unknown";
    if ($arg !~ m/\A(.+)\([^)]+\)\Z/ ) { return (0); }
    $head = $1;
    foreach $name (keys %local_type) {
	$name_type = $local_type{$name};
      # if ($debug==1) {
      # print "ARRAY, head=$head, name=$name, name_type=$name_type";
      # }
	if ($head eq $name &&
	   ($name_type =~ /VEC/ || $name_type =~ /MAT/ )) {
	    $name_type = $component_type{$name_type};
	    $is_declared_array_var = 1;
            $arg_type = $name_type;
	    last;
	}
    }
    ($is_declared_array_var);
}


sub analyse_types {

    local($inp,$type_of) = @_;

    # Analyse the type declaration line

    if ($inp =~ /([A-Z][A-Z0-9]*)[^:]*::[ ]*/) {

        $typ = $1;
        $dec = $POSTMATCH;

        # Look for the declared variables, repeatedly

        while ($dec =~ /([a-zA-Z]\w*)/g) {
            $var = $1;
	    if ($var eq 'DEFAULT_NULL') { last; }
	    if ($var eq 'DEFAULT') { last; }
	    if ($var eq 'NULL') { last; }
	    if ($var eq 'self') { last; }
	    $type_of->{$var} = $typ;    # Add variable to the type table
        }
    }
}

