param(
	[string]$xsltPath,
	[string]$xmlPath
)

$xsltSettings = New-Object System.Xml.Xsl.XsltSettings;
$XmlUrlResolver = New-Object System.Xml.XmlUrlResolver;

$xslt = New-Object System.Xml.Xsl.XslCompiledTransform;
$xslt.Load($xsltPath,$xsltSettings,$XmlUrlResolver);
$outputPath = (New-TemporaryFile).FullName
$xslt.Transform($xmlPath, $outputPath);
cat $outputPath
rm $outputPath
