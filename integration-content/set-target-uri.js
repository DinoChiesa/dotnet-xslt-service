function executeScript(event) {
  var nodeName = event.getParameter("firstNodeName");
  let targetUri = event.getParameter(
    nodeName == "claims"
      ? "`CONFIG_xslt-claims-uri`"
      : "`CONFIG_xslt-circle-uri`",
  );
  event.log(`setting targetUri...`);
  event.setParameter("targetUri", targetUri + "/xml");
}
