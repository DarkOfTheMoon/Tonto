# This script makes the TONTO-nav-bar.html from the .html files.
#
# ! $Id$
#
################################################################################

use File::Spec('abs2rel','canonpath');

$htmldir = $ARGV[0];
$f95docdir = $ARGV[1];
$docdir = $ARGV[2];

opendir DIR,$htmldir;
@dirlist = grep(/_short\.html$/,readdir(DIR));
closedir DIR;

$rel_path = File::Spec->abs2rel($htmldir,$docdir);
$htmldir = File::Spec->canonpath($rel_path);
$rel_path = File::Spec->abs2rel($f95docdir,$docdir);
$f95docdir = File::Spec->canonpath($rel_path);

print "<HTML>\n";
print "<HEAD>\n";
print "  <META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">\n";
print "  <META name=\"robots\" content=\"noindex, nofollow\">\n";
print "  <TITLE>Tonto Navigation</TITLE>\n";
print "  <STYLE type=\"text/css\">";
print "  <!--";
print "   DIV.indent { margin-left : 15px }";
print "  -->";
print "  </STYLE>";
print "<BASE TARGET=\"main\">\n";
print "</HEAD>\n";
print "<body BGCOLOR=\"#FFFFFF\">\n";
print "<DIV CLASS=\"indent\" ALIGN=\"left\">\n";
print "<DIV STYLE=\"background-color : #DDDDEE\">\n";
print "<BR>\n";
print "<IMG SRC=\"logo_150.png\" WIDTH=150 HEIGHT=32>\n";

print "<BR><BR>";
print "<BR><A HREF=\"htmlmanual/index.html\">What is TONTO?</A>\n";
print "<BR><BR>\n";
print "<IMG SRC=\"hr.png\" HEIGHT=10 WIDTH=100%>\n";
print "</DIV>\n";

print "<BR>\n";
print "<DIV STYLE=\"background-color : #DDDDEE\">MODULES</DIV>\n";

foreach $i (@dirlist) {
  $_=$i;
  s/_short\.html$//go;
  push @filelist,$_;
}
@modlist = grep(!/^run_/o,@filelist);
@proglist = grep(/^run_/o,@filelist);

foreach $i (@modlist) {
   print "<BR><A HREF=\"$htmldir/$i\_short.html\">$i</A> <A HREF=\"$htmldir/$i.html\">.foo</A>  <A HREF=\"$f95docdir/$i.F95\">.F95</A>\n";
}

print "<BR><BR>\n";
print "<DIV STYLE=\"background-color : #DDDDEE\">PROGRAMS</DIV>\n";

foreach $i (@proglist) {
   print "<BR><A HREF=\"$htmldir/$i\_short.html\">$i</A> <A HREF=\"foofiles/$i.foo\">.foo</A>  <A HREF=\"$f95docdir/$i.F95\">.F95</A>\n";
}

print "<BR><BR>\n";
print "<IMG SRC=\"hr.png\" HEIGHT=10 WIDTH=100%>\n";
print "</DIV>\n";
print "</BODY>\n";
print "</HTML>\n";
