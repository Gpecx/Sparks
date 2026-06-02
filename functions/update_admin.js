const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

async function run() {
  let uid;
  const emails = ["gabrieladmin@gmail.com", "gabriel@spark.app"];
  for (const email of emails) {
     const byEmail = await db.collection("users").where("email", "==", email).get();
     if (!byEmail.empty) {
        uid = byEmail.docs[0].id;
        break;
     }
  }

  if (!uid) {
    const byName = await db.collection("users").where("displayName", "==", "gabrieladmin").get();
    if (!byName.empty) {
       uid = byName.docs[0].id;
    }
  }

  if (!uid) {
     // vamos tentar procurar apenas a substring
     const allUsers = await db.collection("users").get();
     for (const doc of allUsers.docs) {
        const data = doc.data();
        if (data.email && data.email.includes("gabrieladmin")) {
           uid = doc.id;
           break;
        }
        if (data.displayName && data.displayName.includes("gabrieladmin")) {
           uid = doc.id;
           break;
        }
     }
  }

  if (uid) {
     console.log("Found gabrieladmin UID: " + uid);
     await db.collection("users").doc(uid).update({ subscriptionPlanId: "premium" });
     console.log("Updated to premium successfully.");
  } else {
     console.log("Could not find user gabrieladmin.");
  }
}
run().catch(console.error).finally(() => process.exit(0));
