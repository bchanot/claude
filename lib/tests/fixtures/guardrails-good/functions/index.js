const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

setGlobalOptions({ maxInstances: 10 });

exports.onOrder = onDocumentCreated("orders/{id}", async (event) => {
  await db.collection("receipts").add({ order: event.params.id });
});
