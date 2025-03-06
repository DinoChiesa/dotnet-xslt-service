function executeScript(event) {
  var json = event.getParameter("`Task_5_connectorOutputPayload`");
  var xmlText = json[0].Content;
  if (xmlText) {
    event.setParameter("xml", xmlText);
  } else {
    event.log("no xmlText!");
  }
}
