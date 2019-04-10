<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:trx="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
	<xsl:output method="text" indent="yes" />
	<xsl:template match="/">
		<result>
			<xsl:if test="//trx:ResultSummary/trx:Counters/@total != 1">
				<xsl:call-template name="summary" />
			</xsl:if>
			<xsl:call-template name="details">
				<xsl:with-param name="count" select="//trx:ResultSummary/trx:Counters/@total" />
			</xsl:call-template>
		</result>
	</xsl:template>
	<xsl:template name="summary">
		<summary>
			<total>
Total: <xsl:value-of select="//trx:ResultSummary/trx:Counters/@total"/>
			</total>
			<failed>
Failed: <xsl:value-of select="//trx:ResultSummary/trx:Counters/@failed"/>
			</failed>
		</summary>
	</xsl:template>
	<xsl:template name="details">
		<xsl:param name="count" />
		<details>
			<xsl:for-each select="//trx:UnitTestResult">
				<xsl:if test="(@outcome != 'Passed') or $count = 1">
					<test>
						<result>
T: <xsl:value-of select="@testName"/>
<xsl:text> </xsl:text>
<xsl:choose>
<xsl:when test="@outcome = 'Failed'">FAILED</xsl:when>
<xsl:when test="@outcome = 'Passed'">Passed</xsl:when>
<xsl:otherwise>Inconclusive</xsl:otherwise>
</xsl:choose>
						</result>
						<xsl:if test="@outcome != 'Passed'">
							<message>
	Message: <xsl:value-of select="normalize-space(.//trx:Message)" />
							</message>
							<stackTrace>
	StackTrace: <xsl:value-of select="normalize-space(.//trx:StackTrace)" />
							</stackTrace>
						</xsl:if>
					</test>
				</xsl:if>
			</xsl:for-each>
		</details>
	</xsl:template>
</xsl:stylesheet>
