<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="node()|@*">
     <xsl:copy>
       <xsl:apply-templates select="node()|@*"/>
     </xsl:copy>
  </xsl:template>

  <!--
    Work around floating point bug in QEMU(?)
    See https://gitlab.com/qemu-project/qemu/-/issues/2817
  -->
  <xsl:template match="/domain/cpu">
    <cpu mode="custom" match="exact" check="none">
      <model fallback="forbid">Haswell-noTSX-IBRS</model>
    </cpu>
  </xsl:template>

  <xsl:template match="/domain/devices">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:copy-of select="node()"/>

      <input type="tablet" bus="usb">
        <address type="usb" bus="0" port="1"/>
      </input>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
