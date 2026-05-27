const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function run() {
  let testEnv = await initializeTestEnvironment({
    projectId: "demo-spark",
    firestore: {
      rules: fs.readFileSync("../firestore.rules", "utf8"),
    },
  });

  const chiefId = "chief123";
  const memberId = "member123";
  const clanId = "clan123";

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection("users").doc(chiefId).set({ uid: chiefId, email: "c@c.com", role: "membro", xp: 0, sparkPoints: 0, clanId: clanId });
    await db.collection("users").doc(memberId).set({ uid: memberId, email: "m@m.com", role: "membro", xp: 0, sparkPoints: 0, clanId: clanId });
    await db.collection("clans").doc(clanId).set({ name: "My Clan" });
    await db.collection("clans").doc(clanId).collection("members").doc(chiefId).set({ role: "chefe" });
    await db.collection("clans").doc(clanId).collection("members").doc(memberId).set({ role: "membro" });
  });

  const chiefContext = testEnv.authenticatedContext(chiefId);
  const db = chiefContext.firestore();

  const batch = db.batch();
  
  // Remove o clanId de todos os usuários
  batch.update(db.collection("users").doc(chiefId), { clanId: require('firebase/firestore').FieldValue.delete() });
  batch.update(db.collection("users").doc(memberId), { clanId: require('firebase/firestore').FieldValue.delete() });
  
  batch.delete(db.collection("clans").doc(clanId).collection("members").doc(chiefId));
  batch.delete(db.collection("clans").doc(clanId).collection("members").doc(memberId));
  batch.delete(db.collection("clans").doc(clanId));

  try {
    await batch.commit();
    console.log("Batch succeeded!");
  } catch (e) {
    console.error("Batch failed!", e.message);
  }

  await testEnv.cleanup();
}
run();
