<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                version="1.0">

<!-- tontodocbook will get mapped to the proper directory name in tonto.cat -->
<xsl:import href="tontodocbook/fo/docbook.xsl"/>

<xsl:include href="tonto.common.xsl"/>

<xsl:template match="lineannotation">
  <fo:inline font-style="italic">
    <xsl:call-template name="inline.charseq"/>
  </fo:inline>
</xsl:template>

</xsl:stylesheet>
