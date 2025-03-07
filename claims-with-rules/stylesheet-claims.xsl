<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ext="urn:extension1"
                exclude-result-prefixes="ext">
  <!--
      Copyright © 2024,2025 Google LLC.

      Licensed under the Apache License, Version 2.0 (the "License");
      you may not use this file except in compliance with the License.
      You may obtain a copy of the License at

          https://www.apache.org/licenses/LICENSE-2.0

      Unless required by applicable law or agreed to in writing, software
      distributed under the License is distributed on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
      See the License for the specific language governing permissions and
      limitations under the License.

  -->

  <xsl:output omit-xml-declaration="yes" method="xml" encoding="UTF-8"
              indent="yes"/>

  <xsl:param name="indent-increment" select="''"/>

  <xsl:template match="/claims">
    <xsl:if test="claim">
      <claims>
        <xsl:for-each select="claim">
          <xsl:call-template name="newline"/>
          <!-- this extension object returns a NodeSet -->
          <xsl:apply-templates
              select="ext:ProcessClaim(./procedureCode,./amount,./patientId)"/>
        </xsl:for-each>
        <xsl:call-template name="newline"/>
      </claims>
    </xsl:if>
  </xsl:template>

  <!-- get the indentation right for claim elements. -->
  <!-- from https://github.com/harvard-lts/fits/blob/main/xml/prettyprint.xslt -->
  <xsl:template match="*">
    <xsl:param name="indent" select="'  '"/>
    <xsl:value-of select="$indent"/>
    <xsl:choose>
      <xsl:when test="count(child::*) > 0">
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:apply-templates select="*|text()">
            <xsl:with-param name="indent" select="concat ($indent, $indent-increment)"/>
          </xsl:apply-templates>
          <xsl:value-of select="$indent"/>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="newline">
    <xsl:text disable-output-escaping="yes">&#xA;</xsl:text>
  </xsl:template>

  <xsl:template match="/*" priority="0">
    <none/>
  </xsl:template>

</xsl:stylesheet>
