#--------------------------------------------------------------------------------
#
#  >>> Make the module dependecy list
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
  $name = lc($_);  # Get the line
  last LINE if /^ +contains.*$/;
  if ($name =~ "^ *module +")  {
     $name =~ s/^ *module +//g;
     $unitname = $name;
     $is_module = 1; }
  elsif ($name =~ "^ *program +")  {
     $name =~ s/^ *program +//g;
     $unitname = $name;
     $is_program = 1; }
  elsif ($name =~ "^ *use +") {
     $name =~ s/^ *use +//g;
     $name =~ s/[ ,]+.*//g; # get rid of stuff after the comma.
     next LINE if ($name =~ /service_routines/); # not a real module to use.
     $n++;
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
