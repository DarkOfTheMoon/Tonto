# This script makes the TONTO-nav-bar.html from the .html files.
#
# ! $Id$
#
################################################################################

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

opendir DIR,$ARGV[0];
@dirlist = grep(/_short\.html$/,readdir(DIR));

foreach $i (@dirlist) {
  $_=$i;
  s/_short\.html$//go;
  push @filelist,$_;
}
@modlist = grep(!/^run_/o,@filelist);
@proglist = grep(/^run_/o,@filelist);

foreach $i (@modlist) {
   print "<BR><A HREF=\"htmlfiles/$i\_short.html\">$i</A> <A HREF=\"htmlfiles/$i.html\">.foo</A>  <A HREF=\"f95files/$i.F95\">.F95</A>\n";
}

print "<BR><BR>\n";
print "<DIV STYLE=\"background-color : #DDDDEE\">PROGRAMS</DIV>\n";

foreach $i (@proglist) {
   print "<BR><A HREF=\"htmlfiles/$i\_short.html\">$i</A> <A HREF=\"foofiles/$i.foo\">.foo</A>  <A HREF=\"f95files/$i.F95\">.F95</A>\n";
}

print "<BR><BR>\n";
print "<IMG SRC=\"hr.png\" HEIGHT=10 WIDTH=100%>\n";
print "</DIV>\n";
print "</BODY>\n";
print "</HTML>\n";
