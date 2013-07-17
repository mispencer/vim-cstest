<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="text" indent="yes" />
	<xsl:template match="/">
		<result>
			<xsl:if test="//test-results/@total &gt; 1">
				<xsl:call-template name="summary" />
			</xsl:if>
			<xsl:call-template name="details" />
		</result>
	</xsl:template>
	<xsl:template name="summary">
		<summary>
			<total>
Total: <xsl:value-of select="//test-results/@total"/>
			</total>
			<failed>
Failed: <xsl:value-of select="//test-results/@errors"/>
			</failed>
		</summary>
	</xsl:template>
	<xsl:template name="details">
		<details>
			<xsl:for-each select="//test-case">
				<xsl:if test="@result != 'Success' or //test-results/@total &lt; 2">
					<test>
						<result>
T: <xsl:value-of select="@name"/>
<xsl:text> </xsl:text>
<xsl:choose>
<xsl:when test="@result = 'Error'">FAILED</xsl:when>
<xsl:when test="@result = 'Failure'">FAILED</xsl:when>
<xsl:when test="@result = 'Success'">Passed</xsl:when>
<xsl:otherwise>Inconclusive</xsl:otherwise>
</xsl:choose>
						</result>
						<xsl:if test="@result = 'Error' or @result = 'Failure'">
							<message>
	Message: <xsl:value-of select="normalize-space(.//message)" />
							</message>
							<stackTrace>
	StackTrace: <xsl:value-of select="normalize-space(.//stack-trace)" />
							</stackTrace>
						</xsl:if>
					</test>
				</xsl:if>
			</xsl:for-each>
		</details>
	</xsl:template>
</xsl:stylesheet>
