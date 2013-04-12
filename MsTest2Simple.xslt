<?xml version="1.0" encoding="utf-8"?> 
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:vs="http://microsoft.com/schemas/VisualStudio/TeamTest/2010"> 
	<xsl:output method="text" indent="yes" />
	<xsl:template match="/"> 
		<result>
			<xsl:if test="//vs:ResultSummary/vs:Counters/@total &gt; 1">
				<xsl:call-template name="summary" /> 
			</xsl:if>
			<xsl:call-template name="details" /> 
		</result>
	</xsl:template> 
	<xsl:template name="summary"> 
		<summary> 
			<total>
Total: <xsl:value-of select="//vs:ResultSummary/vs:Counters/@total"/> 
			</total> 
			<failed>
Failed: <xsl:value-of select="//vs:ResultSummary/vs:Counters/@failed"/>
			</failed> 
			<passed>
Passed: <xsl:value-of select="//vs:ResultSummary/vs:Counters/@passed"/>
			</passed> 
		</summary>
	</xsl:template> 
	<xsl:template name="details"> 
		<details>
			<xsl:for-each select="//vs:Results/vs:UnitTestResult"> 
				<xsl:if test="@outcome != 'Passed' or //vs:ResultSummary/vs:Counters/@total &lt; 2">
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
						<xsl:if test="@outcome = 'Failed'">
							<message>
	Message: <xsl:value-of select=".//vs:Message" />
							</message>
							<stackTrace>
	StackTrace: <xsl:value-of select=".//vs:StackTrace" />
							</stackTrace>
						</xsl:if>
					</test>
				</xsl:if>
			</xsl:for-each> 
		</details>
	</xsl:template> 
</xsl:stylesheet>
