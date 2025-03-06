function executeScript(event) {
  var json = JSON.parse(event.getParameter("dataJson"));
  var payload = {
    type: typeof json,
    Bucket: json.bucket || "default",
    ObjectFilePath: json.id ? json.id.split("/")[1] : "object-name",
  };
  event.log(`setting connectorInputPayload...`);
  event.setParameter("`Task_5_connectorInputPayload`", payload);
}
