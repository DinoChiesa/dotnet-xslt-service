<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ext="urn:extension1"
                exclude-result-prefixes="ext">
  <!--
      Copyright © 2024 Google LLC.

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

  <xsl:template match="/data">
    <xsl:if test="circle">
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
    </xsl:if>
  </xsl:template>

  <xsl:template match="/*" priority="0">
    <none/>
  </xsl:template>

</xsl:stylesheet>
