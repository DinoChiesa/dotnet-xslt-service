<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ext="urn:extension1"
                exclude-result-prefixes="ext">

  <xsl:output omit-xml-declaration="yes" method="xml" encoding="UTF-8"
              indent="yes" />

  <xsl:template match="data">
    <circles>
      <calc-time>
        <xsl:value-of select="ext:Timestamp()"/>
      </calc-time>
      <xsl:for-each select="circle">
        <circle>
          <xsl:copy-of select="node()"/>
          <circumference>
            <xsl:value-of select="ext:Circumference(./radius)"/>
          </circumference>
        </circle>
      </xsl:for-each>
    </circles>
  </xsl:template>
</xsl:stylesheet>
