## foo2html.perl
## $Id$
use English;            # Get rid of horrible Perl short forms

$, = ' ';		# set output field separator
$\ = "\n";		# set output record separator

$inp = ' ';             # current processed input line

$ExitValue = 0;

## -----------------------------------------------------------------------------
## Define the .foo file, long and short documentation files
## -----------------------------------------------------------------------------

@ARGV==1             or die "Must supply one file name without .foo extension,";
$ARGV[0] !~ /\.foo$/ or die "Must supply file name without .foo extension,";

$foofile = $ARGV[0] . '.foo';        # This is the .foo file to work on

open(FOOFILE,$foofile) or die "$FOOFILE does not exist,";

$long = 'long';                      # long routine name
system("/bin/rm -f $long");

open(LONG,">".$long);

print LONG '<html>';
print LONG "<head>";
print LONG "  <META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">";
print LONG "  <META name=\"robots\" content=\"noindex, nofollow\">";
print LONG "  <TITLE>Documentation for $ARGV[0]</TITLE>";
print LONG "</head>";
print LONG "<body BGCOLOR=\"#FFFBF0\"><BASEFONT SIZE=2>";
print LONG '<pre>';

$short = 'short';
system("/bin/rm -f $short");

open(SHORT,">".$short);              # short routine name

print SHORT '<html>';
print SHORT "<head>";
print SHORT "  <META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">";
print SHORT "  <META name=\"robots\" content=\"noindex, nofollow\">";
print SHORT "  <TITLE>Documentation for $ARGV[0]</TITLE>";
print SHORT "</head>";
print SHORT "<body BGCOLOR=\"#FFFBF0\"><BASEFONT SIZE=2>";
print SHORT '<pre>';
print SHORT '<B>Synopsis:</B>';

## -----------------------------------------------------------------------------
## Set up the components of known vector types            
## -----------------------------------------------------------------------------

%component_type = (     # Components of the vector types
    'VEC'      => 'DBL',
    'IVEC'     => 'INT',
    'CVEC'     => 'CDBL',
    'BINVEC'   => 'BIN',
    'STRVEC'   => 'BIN',
    'VECVEC'   => 'VEC_',
    'IVECVEC'  => 'IVEC_',
    'MATVEC'   => 'MAT_',
    'MAT3VEC'  => 'MAT3_',
    'SHELLVEC' => 'SHELL',
    'BASISVEC' => 'BASIS',
    'ATOMVEC'  => 'ATOM',
    'IRREPVEC' => 'IRREP',
    'MAT'      => 'DBL',
    'IMAT'     => 'INT',
    'CMAT'     => 'CDBL',
    'MAT3'     => 'DBL',
    'IMAT3'    => 'INT',
    'CMAT3'    => 'CDBL',
    'MAT4'     => 'DBL',
    'IMAT4'    => 'INT',
    'CMAT4'    => 'CDBL',
    'MAT5'     => 'DBL',
    'IMAT5'    => 'INT',
    'CMAT5'    => 'CDBL',
);

## -----------------------------------------------------------------------------
## Set up some substitutions which always apply
## -----------------------------------------------------------------------------

## %subst = (          # Substitutions .................
##     ' STR '      => ' STR(STR_SIZE) ',
##     ' BSTR '     => ' STR(BSTR_SIZE) ',
##     ' TRI '      => ' TRI(:) ',
##     ' VEC '      => ' VEC(:) ',
##     ' VECVEC '   => ' VECVEC(:) ',
##     ' IVEC '     => ' IVEC(:) ',
##     ' IVECVEC '  => ' IVECVEC(:) ',
##     ' CVEC '     => ' CVEC(:) ',
##     ' MATVEC '   => ' MATVEC(:) ',
##     ' MAT3VEC '  => ' MAT3VEC(:) ',
##     ' MAT4VEC '  => ' MAT4VEC(:) ',
##     ' STRVEC '   => ' STRVEC(:) ',
##     ' BINVEC '   => ' BINVEC(:) ',
##     ' FILEVEC '  => ' FILEVEC(:) ',
##     ' SHELLVEC ' => ' SHELLVEC(:) ',
##     ' BASISVEC ' => ' BASISVEC(:) ',
##     ' ATOMVEC '  => ' ATOMVEC(:) ',
##     ' IRREPVEC ' => ' IRREPVEC(:) ',
##     ' MAT '      => ' MAT(:,:) ',
##     ' MAT3 '     => ' MAT3(:,:,:) ',
##     ' MAT4 '     => ' MAT4(:,:,:,:) ',
##     ' MAT5 '     => ' MAT5(:,:,:,:,:) ',
##     ' IMAT '     => ' IMAT(:,:) ',
##     ' IMAT3 '    => ' IMAT3(:,:,:) ',
##     ' IMAT4 '    => ' IMAT4(:,:,:,:) ',
##     ' CMAT '     => ' CMAT(:,:) ',
##     ' CMAT3 '    => ' CMAT3(:,:,:) ',
##     ' CMAT4 '    => ' CMAT4(:,:,:,:) ',
##     ' CMAT5 '    => ' CMAT5(:,:,:,:,:) ',
##     ' STR,'      => ' STR(STR_SIZE),',
##     ' BSTR,'     => ' STR(BSTR_SIZE),',
##     ' TRI,'      => ' TRI(:),',
##     ' VEC,'      => ' VEC(:),',
##     ' VECVEC,'   => ' VECVEC(:),',
##     ' IVEC,'     => ' IVEC(:),',
##     ' IVECVEC,'  => ' IVECVEC(:),',
##     ' CVEC,'     => ' CVEC(:),',
##     ' MATVEC,'   => ' MATVEC(:),',
##     ' MAT3VEC,'  => ' MAT3VEC(:),',
##     ' MAT4VEC,'  => ' MAT4VEC(:),',
##     ' STRVEC,'   => ' STRVEC(:),',
##     ' BINVEC,'   => ' BINVEC(:),',
##     ' FILEVEC,'  => ' FILEVEC(:),',
##     ' SHELLVEC,' => ' SHELLVEC(:),',
##     ' BASISVEC,' => ' BASISVEC(:),',
##     ' ATOMVEC,'  => ' ATOMVEC(:),',
##     ' IRREPVEC,' => ' IRREPVEC(:),',
##     ' MAT,'      => ' MAT(:,:),',
##     ' MAT3,'     => ' MAT3(:,:,:),',
##     ' MAT4,'     => ' MAT4(:,:,:,:),',
##     ' MAT5,'     => ' MAT5(:,:,:,:,:),',
##     ' IMAT,'     => ' IMAT(:,:),',
##     ' IMAT3,'    => ' IMAT3(:,:,:),',
##     ' IMAT4,'    => ' IMAT4(:,:,:,:),',
##     ' CMAT,'     => ' CMAT(:,:),',
##     ' CMAT3,'    => ' CMAT3(:,:,:),',
##     ' CMAT4,'    => ' CMAT4(:,:,:,:),',
##     ' CMAT5,'    => ' CMAT5(:,:,:,:,:),',
## );

## -----------------------------------------------------------------------------
## Set up the scoping units and patterns which detect them
## -----------------------------------------------------------------------------

$scopeunit = "";
$newscopeunitfound = 0;
$ns = 0;                # Scoping unit depth
$scope{$ns} = "?";

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
## Code switches
## -----------------------------------------------------------------------------

$first_contains = 0;                 # set to 1 after first contains found

$first_type = 0;                     # set to 1 after first type found
$first_type_end = 0;                 # set to 1 after first end type found
$first_active_line = 0;
$first_var_dec = 0;        # set to 1 after first argument variable declaration in routine
$first_decl = 0;           # set to 1 after first declaration in routine
$first_ensure = 0;         # set to 1 after first ensure statement in routine
$first_comment = 0;        # set to 1 after first comment in routine
$first_type_comment = 0;
$first_routine_line = 0;   # set to 1 only for the first routine line
$first_rout_interface = 0; # set to 1 if first routine interface is found

$suppress_long_print = 0;
$suppress_short_print = 0;

$first_interface = 1;

$in_routine = 0;

$nuse = 0;# no of use modules

## -----------------------------------------------------------------------------
## Analyse the types.foo file
## -----------------------------------------------------------------------------

open(TYPES,'types.foo');

# Search for a type line

while (chop($X = <TYPES>)) {
    
    last if ($X =~ /^end/ );                        # End of types.foo
    next if ($X !~ /type +([a-zA-Z]\w*)_type\b/);   # Look for next type definition

    $type_name = uc($1);                            # Get the type name
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

line: while (<FOOFILE>) {

    chop;	# strip record separator

    $inp = $_;  # Get the line

    ############################################################################

    if ($inp =~ '^!' && $ns == 0 && $inp !~ '---' ) {
	$inp =~ s/! */   /;        # Synopsis  
	print SHORT $inp;
	$suppress_long_print = 1;
    }

    ############################################################################

    elsif ($first_type == 1 && $first_type_end == 0 && $scope{$ns} eq 'module') {

	if ($inp =~ "^! *end( |\$)" ) {
	    $first_type_end = 1;
	}
	else {
	    #  print "inp=",inp >> short
	    if ($inp =~ '((?:[A-Z][^ ]*(?:, )?)+) *:: *([a-zA-Z_0-9]+)' ) {
		$dec = $1;
		$var = $2;
		$tmp = $var . ' :: ' . $dec;
		print SHORT "   <B><EM><A NAME=\"$var\"><FONT COLOR=\"008800\">$tmp</FONT></A></EM></B>\n";
		$first_type_comment = 0;
	    }
	    else {
                $tmp = $inp;
		$tmp =~ s/! *! */      /;
		$tmp =~ s/! *//;
		if ($first_type_comment == 0) {
		    #  print " " >> short 
		    $first_type_comment = 1;
		}
		print SHORT $tmp;
	    }
	}
    }

    ############################################################################

    elsif ($inp =~ '^! *type ' && $first_type == 0 && $scope{$ns} eq 'module') {
	# Use list and type definition #############
	if ($nuse >= 1) {
	    $uselist = "   $usedname[1]";
	    print SHORT ' ';
	    print SHORT "<B>Used modules:</B>";
	    print SHORT ' ';
	    $cont = 1;
	    for ($i = 2; $i <= $nuse; $i++) {
		if (length($uselist) > 70 * $cont) {
		    $uselist = "$uselist\n   $usedname[$i]";
		    $cont = $cont + 1;
		}
		else {
		    $uselist = "$uselist, $usedname[$i]";
		}
	    }
	    print SHORT $uselist;
	}
	print SHORT ' ';
	print SHORT '<B>Type components:</B>';
	$first_type = 1;
    }

    ############################################################################

    elsif ($inp =~ '[a-z_A-Z]' && $inp !~ '^[ ]*[!#]' ) {

	# if not blank do the following ...

	if ( $first_active_line == 0             &&
            ($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function') &&
             $scope{$ns-1} eq 'contains'         &&
	     $inp !~ '[A-Z][A-Z0-9]*[^:]*::[ ]*' &&
	     $inp !~ '^ *ENSURE'                 &&
	     $inp !~ /^ *end/             ) { 
           if ($inp !~ / *interface/) {
               $first_active_line = 1; 
               undef %arglist;
           #   print "activ=$inp";
           }
	   print LONG ' ';
        }

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
	########################################################################

	if ($newscopeunitfound) {

	    $newscopeunitfound = 0;

	    if ($scopeunit eq 'module') {

                # Get the module name #

		$inp =~ /^[ ]*module ([A-Z][A-Z_0-9]*)\b/;           
		$long_module_name = $1;
		$long_module_name =~ /^([A-Z0-9]*)/;
                $modname = lc($long_module_name);
		$module_name = $1;

                # Assign the self type

	        $global_type{'self'} = $module_name;                 

	    }
	    elsif ($scopeunit eq 'interface' && $scope{$ns-1} eq 'module') {

		# Change the interface #

		$inp =~ '^[ ]*interface ([a-zA-Z0-9_]+)';
		$name = $1;
		if ($first_interface) {
		    print SHORT ' ';
		    print SHORT '<B>Generic interfaces:</B>';
		    $first_interface = 0;
		}
		print SHORT ' ';
		print SHORT "   <B><EM><A NAME=\"$name\"><FONT COLOR=\"EE0000\">interface $name:</FONT></A></EM></B>";
		print SHORT '';
	    }
	    elsif ($scopeunit eq 'interface') {
		print SHORT ' ';
		print SHORT $inp;
                $suppress_short_print = 1
	    }
	    elsif ($scopeunit eq 'contains') {
		$first_contains = 1;
		print SHORT ' ';
		print SHORT '<B>Method components:</B>';
	    }
                                                       # end found #############
	    elsif ($scopeunit eq 'empty-end' ) {

	        $ns = $ns - 1; 
	        if ($scope{$ns} eq 'contains') { $ns = $ns - 1; }

		if (($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function') && $ns <= 3) {
		    # end Module routine. need ns<=3 to eliminate interface routines
                    # Delete the local type table

                    undef %local_type;
                    $local_type{'variable name X'} = 'type of the variable X';
		}

		if (($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function')) {

		    if ($scope{$ns-1} eq 'interface')  { print SHORT $inp; }
		    if ($scope{$ns-1} eq 'contains')   { $in_routine = 0; }
		    $first_active_line = 0;
		    $first_var_dec = 0;
		    $first_decl = 0;
		    $first_ensure = 0;
		    $first_comment = 0;
	            $first_routine_line = 0; 
		}
		elsif ($scope{$ns} eq 'interface' && 
		      ($scope{$ns-1} eq 'subroutine' || $scope{$ns-1} eq 'function')) {
		    print SHORT $inp;
	            $first_rout_interface = 0; 
		}

	        $ns = $ns - 1; 

	        if ($ns < 0) {
		    print 'FOO error: unmatched end';
		    $ExitValue = 1;
                    last line;
	        }
            }
                                             #  explicit end <scope> ######
	    elsif ($scope{$ns} eq 'named-end' ) {

	        $ns = $ns - 1; 
	        if ($scope{$ns} eq 'contains') { $ns = $ns - 1; }
	        $ns = $ns - 1; 

	        if ($ns < 0) {
		    print 'FOO error: unmatched end';
		    $ExitValue = 1;
                    last line;
	        }
            }
	}

	########################################################################

	elsif ($scope{$ns} eq 'program' || $scope{$ns} eq 'module') {

	    # Within a program ##############################

	    if ($inp =~ '[A-Z][A-Z0-9]*[^:]*::[ ]*' ) { &analyse_types($inp,\%global_type); }

	    if ($inp =~ '^ *use *([A-Z_0-9]+)' ) {
		$nuse = $nuse + 1;
		$usedname[$nuse] = $1;
	    }
	}

	########################################################################

	elsif ($scope{$ns} eq 'interface' && $scope{$ns-1} eq 'module') {

	    # expecting a module procedure ###############

	    $inp =~ '([a-zA-Z_0-9]+)';            # add a module procedure
	    $rout = $1;
	    $name = $POSTMATCH;
	    $interfacelist = "   <B><EM><A HREF=\"${modname}_short.html#${rout}\"><FONT COLOR=\"EE0000\">${rout}</FONT></A></EM></B>";
	    $cont = 1;
	    $cnt = 1;

	    while ($name =~ m/([a-zA-Z_0-9]+)/g ) {
		if ($cnt > 1) {
		    $inp = $inp . ', ';
		}
		if (length($interfacelist) > 500 * $cont) {
		    $interfacelist = $interfacelist . "\n   ";
		    $cont = $cont + 1;
		}
		$rout = $1;
		$routine_int{$rout} = 1;
		$cnt = $cnt + 1;
		$interfacelist = $interfacelist .
                                 ", <B><EM><A HREF=\"${modname}_short.html#${rout}\"><FONT COLOR=\"EE0000\">${rout}</FONT></A></EM></B>";
	    }
	    print SHORT $interfacelist;
	}

	########################################################################

	elsif ($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function') {

	    # Within a routine ##############################

	    if ($inp =~ '[A-Z][A-Z0-9]*[^:]*::[ ]*' ) { &
               analyse_types($inp,\%local_type); 
	       if ($first_decl == 0) {
	          print LONG ' ';
		  $first_decl = 1;
	       }
            }
	}

	########################################################################

	elsif ($scope{$ns} eq 'interface' || $ns == 0) {

	    # expecting function interface declaration ######

	    &analyse_rout_name($inp);                             # analyse the routine name

	    print SHORT $inp;
	}

	########################################################################

	elsif ($scope{$ns} eq 'contains') {

	    # expecting a subroutine/function line #######

	    &analyse_rout_name($inp);      # analyse the routine name
	    &store_arglist($args_only);    # arguments

	    $short_routine_name = $name;

	    if (&overloaded($name)) {                       # Overloaded routine
		$routine_cnt{$name}++;
		$name = "$name" . "_" . "$routine_cnt{$name}" ;
	    }
	    else {
		$routine_cnt{$name} = 0;
	    }


	    $real_routine_name = $name;

	    $first_active_line = 0;    # first active line of code not found yet
	    $first_var_dec = 0; 
	    $first_decl = 0; 
	    $first_ensure = 0; 
	    $first_comment = 0; 
	    $first_routine_line = 1; 

	    print SHORT ' ';

	    print SHORT
		  "   <B><EM><A NAME=\"${real_routine_name}\"></A><A HREF=\"${modname}.html#${real_routine_name}\"><FONT COLOR=\"FF0000\">${short_routine_name}</FONT></A><FONT COLOR=\"FF0000\">${args_only}</FONT></EM></B>";

	    print LONG ' ';
	    print LONG
		  "   <B><EM><A NAME=\"${real_routine_name}\"></A><A HREF=\"${modname}_short.html#${real_routine_name}\"><FONT COLOR=\"FF0000\">${name_and_args}</FONT></A></EM></B>";

	    $suppress_long_print = 1;
	    $suppress_short_print = 1;

            # Assign global variable types to local

            %local_type = %global_type
	}

	########################################################################

	elsif ($scope{$ns} eq 'type') {
	    # Within a type declaration ###################
	    # if (match(inp,"[A-Z][A-Z0-9]*[^:]*::[ ]*")) {
	    #                                    # Analyse the type declaration line
	    #    analyse_tonto_derived_type(inp,module_name) 
	    # }

	    ;
	}
    }

    ############################################################################
    ########################################  STACK, UNSTACK, and CHECK ########
#if ($first_active_line == 0      && 
#    $first_routine_line == 0     && 
#           $scope{$ns-1} eq "contains"  &&  
#           $inp =~ /^ *[a-zA-Z.]/       &&
#    $inp !~ /^ *end/             && 
#    $inp !~ /::/                 ) {
#    $first_active_line = 1;
#           undef %arglist;
#}

    if (($scope{$ns} eq 'subroutine' || $scope{$ns} eq 'function')) {

	if ($first_active_line == 0 && $inp =~ ' ENSURE' ) {

	    # sub("ENSURE","<FONT COLOR=\"EE0000\">ENSURE",inp)
	    # sub("$","</FONT>",inp)

	    if ($first_ensure == 0) {
		print SHORT ' ';
		$first_ensure = 1;
		print LONG ' ';
	    }
	    print SHORT $inp;
	}

	elsif ($first_active_line == 0 && $inp =~ '^ *!' ) {

	    $tmp = $inp;               # for comments
	    $tmp =~ s/ *! */      /;

	    if ($first_comment == 0) {
		print SHORT ' ';
		$first_comment = 1;
		print LONG ' ';
	    }
	    print SHORT $tmp;
	}

	elsif ($scope{$ns-1} eq 'contains') {

	    if ($narg > 0) {

		# for declarations

		if ($inp =~ '::' && &contains_arg($inp) == 1 && $iarg > 0 && $suppress_short_print == 0) {

		    # sub("[A-Z]","<FONT COLOR=\"EE0000\">&",inp)
		    # sub("$","</FONT>",inp)

                    $tmp = $inp;
                    $tmp =~ s/^ */      /;

		    if ($first_var_dec == 0) {
			print SHORT ' ';
			$first_var_dec = 1;
		    }
		    print SHORT $tmp;

		    # print inp >> long
		    # suppress_long_print = 1
		    $iarg = $iarg - 1;
		}
	    }
	}

	elsif ($scope{$ns-1} eq 'interface') {
            if ($first_rout_interface==0) { 
               $first_rout_interface = 1;
            }
            else { 
               print SHORT $inp; 
            }
	}
    }

    ############################################################################

    $rep = 0;

    if ($inp =~ '[a-z_A-Z.]' && $inp !~ '^[ ]*[!#]' ) { # if not blank do the following ...

    	########################################################################
	############################## lines that contain a dot. ###############
	if ($inp =~ '.[.].') {

	############################### Change self "." expressions on all lines


	while ($inp =~         /((?:^|;|[)] ) *)[.]([a-zA-Z_]\w*)(.*)/  ||
               $inp =~ '((?:[(=+-/*<>,:]|\w ) *)[.]([a-zA-Z_]\w*)(.*)'     ) {
	    $rep  = $rep + 1;
            $pre  = $PREMATCH . $1;
            $rout = $2;
            $post = $3;
            $rout{$rep} = $rout;
	    if (&has_field('self', $rout)) { 
               $inp  = $pre . "self%X$rep" . $rout . "X$rep". $post; 
               $comp{$rep} = "yes"; 
            }
	    else  { 
               $inp  = $pre . "%X$rep" . $rout . "X$rep". $post; 
               $comp{$rep} = "no"; 
            }
            $modu{$rep} = lc($module_name);
	}

	########################################################################
	####################################### change variable "." expressions 

	while ($inp =~ '((?:^|;|[)] ) *)([a-zA-Z_][\w%]*(?:[(][\w%,:+-]*[)][\w%]*){0,4})[.]([a-zA-Z_]\w*)(.*)'   ||
	       $inp =~ '((?:[(=+-/*<>,:]|\w ) *)([a-zA-Z_][\w%]*(?:[(][\w%,:+-]*[)][\w%]*){0,4})[.]([a-zA-Z_]\w*)(.*)'   ||
	       $inp =~ '((?:[(=+-/*<>,:]|\w ) *)([\w%]*(?:[(](?: *[\w%]*(?:[(][\w%,:+-]*[)][\w%]*){0,4}[ ]*[+-/*<>]*){1,3}[)]){0,1})[.]([a-zA-Z_]\w*)(.*)' ) {
	    $rep  = $rep + 1;
            $pre  = $PREMATCH . $1 ;
            $arg  = $2;
            $rout = $3;
            $post = $4;
	    $inp  = $pre . $arg . "%X$rep" . $rout . "X$rep" . $post; 
            $rout{$rep} = $rout;
	    if (&has_field($arg, $rout)) { $comp{$rep} = "yes"; }
	    else                         { $comp{$rep} = "no"; }
            $modu{$rep} = lc($arg_type);
	}
	}
    }

    ################################################## Make the HTML tags ######
    $inp =~ s/&/\&amp;/g;
    $inp =~ s/</\&lt;/g;
    $inp =~ s/>/\&gt;/g;

    foreach $rep (keys %rout) {
       $rout = $rout{$rep};
       $modu = $modu{$rep};
       $comp = $comp{$rep};
    #  print "rep=$rep, modu=$modu, rout=$rout, is_comp=$comp{$rep}";
       if ($comp eq "yes") { $inp =~ s|(self)?%X$rep.*X$rep|.<A HREF=\"${modu}_short.html#$rout\"><B><FONT COLOR=\"008800\">$rout</FONT></B></A>|; }
       else                { $inp =~ s|(self)?%X$rep.*X$rep|.<A HREF=\"${modu}_short.html#$rout\"><B><FONT COLOR=\"EE0000\">$rout</FONT></B></A>|; }
    #  print "inp=$inp";
    }

    $rep = 0;
    undef %rout;
    undef %modu;
    undef %comp;

    if ($inp =~ '-----' )             { $suppress_long_print = 1; }
    if ($inp =~ "^ *contains( |\$)" ) { $suppress_long_print = 1; }
    if ($first_contains == 0)         { $suppress_long_print = 1; }
    if ($suppress_long_print == 0) {
	print LONG $inp;                            # Print the processed line!
    }
    $suppress_long_print = 0;
    $suppress_short_print = 0;

    ############################################################################
    ############################################################################
    ############################################################################

}

print SHORT '</pre>';
print SHORT '</body>';
print SHORT '</html>';

$name = lc($long_module_name);
system("mv -f short ${name}_short.html");

print LONG '</pre>';
print LONG '</body>';
print LONG '</html>';

system("mv -f long ${name}.html");

exit $ExitValue;


##==========================================================================

sub analyse_rout_name {

    local($inp) = @_;

    # Analyse routine attributes (in square brackets)

    $is_function = 0;
    if ($inp =~ / result[ ]*[(]/ )        { $is_function = 1; }
    $is_functional = 0;
    $is_routinal = 0;
    $pure = 0;
    if ($inp =~ s/ \[functional]// )      { $is_functional = 1; }
    if ($inp =~ s/ \[routinal]// )        { $is_routinal = 1; }
    $attr = '';
    if ($inp =~ s/ \[pure]// )            { $attr = 'PURE ';             $pure = 1; }
    if ($inp =~ s/ \[always_pure]// )     { $attr = 'ALWAYS_PURE ';      $pure = 1; }
    if ($inp =~ s/ \[elemental]//)        { $attr = 'ELEMENTAL ';        $pure = 1; }
    if ($inp =~ s/ \[always_elemental]//) { $attr = 'ALWAYS_ELEMENTAL '; $pure = 1; }
    if ($inp =~ s/ \[recursive]// )       { $attr = "${attr}recursive "; }

    # Analyse the routine name

    $inp =~ /([a-zA-Z]\w*)/;
    $pre  = $PREMATCH;                    # preceding string for the routine
    $name = $1;                           # routine name
    $args_only = $POSTMATCH;
    $args_only =~ s/ *$//;
    $name_and_args = $name . $args_only;

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
    while ($args =~ /(\w*)/g) {
       $narg++;
       $arglist{$1} = $narg;
    }
    $iarg = $narg;
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

sub has_field {
    local($arg, $name) = @_;
    $arg_type = "unknown";
    $arg2  = $arg;
    $arg2  =~ s/%(X[0-9]*)([a-zA-Z]\w*)\1/%$2/g;  # The cross ref begins after the %
    $has_name_as_field = 0;
    if (&is_array_var($arg2)) {
        if (defined $tonto_type{$arg_type}{$name} ) { 
	    $has_name_as_field = 1;
	    $dotvar = "${arg2}%${name}";
	    $local_type{$dotvar} = $tonto_type{$arg_type}{$name};
	}
	return ($has_name_as_field);
    }
    if (&is_var($arg2)) {
	if (defined $tonto_type{$arg_type}{$name}) { 
	    $has_name_as_field = 1;
	    $dotvar = "${arg2}%${name}";
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
#           print "var=",$var,"type=",$typ;
        }
    }
}

