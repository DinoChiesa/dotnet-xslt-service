local f = import "functions";
local xml = std.extVar("xml");
local xsl = std.extVar("`CONFIG_first-node-name-xsl`");
{
  firstNodeName: f.xsltTransform(xml, xsl)
}
