const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "spark-v1-e0eb5"
});

const db = admin.firestore();
const auth = admin.auth();

async function run() {
  try {
    console.log("Iniciando verificação de órfãos...");
    
    // Pega todos os usuários do Auth
    const authUsers = new Set();
    let pageToken = undefined;
    do {
      const listUsersResult = await auth.listUsers(1000, pageToken);
      listUsersResult.users.forEach(user => authUsers.add(user.uid));
      pageToken = listUsersResult.pageToken;
    } while (pageToken);
    
    console.log(`Encontrados ${authUsers.size} usuários no Firebase Auth.`);

    // Pega todos os usuários da coleção 'users'
    const usersSnap = await db.collection("users").get();
    console.log(`Encontrados ${usersSnap.size} documentos na coleção 'users'.`);

    const orphans = [];
    usersSnap.forEach(doc => {
      if (!authUsers.has(doc.id)) {
        orphans.push(doc.id);
      }
    });

    console.log(`Total de contas órfãs encontradas: ${orphans.length}`);
    if (orphans.length === 0) {
      console.log("Nenhuma conta órfã para limpar.");
      return;
    }

    console.log("Órfãos encontrados:", orphans);
    console.log("=== INICIANDO LIMPEZA ===");

    for (const uid of orphans) {
      console.log(`\nLimpando dados para o UID: ${uid}`);

      // 1. users/{uid} e subcoleções
      const subcollections = await db.collection("users").doc(uid).listCollections();
      for (const sub of subcollections) {
        const subDocs = await sub.get();
        const batch = db.batch();
        subDocs.forEach(d => batch.delete(d.ref));
        if (subDocs.size > 0) {
          await batch.commit();
          console.log(`  - Deletados ${subDocs.size} docs da subcoleção users/${uid}/${sub.id}`);
        }
      }
      await db.collection("users").doc(uid).delete();
      console.log(`  - Deletado users/${uid}`);

      // 2. public_profiles/{uid}
      await db.collection("public_profiles").doc(uid).delete();
      console.log(`  - Deletado public_profiles/${uid}`);

      // 3. Remover de clans
      const clansSnap = await db.collection("clans").where("members", "array-contains", uid).get();
      for (const clanDoc of clansSnap.docs) {
        const clanData = clanDoc.data();
        if (clanData.leaderId === uid) {
          // Se for líder, deletar o clã inteiro ou passar a liderança
          // Simplificando: vamos deletar o clã se o líder for deletado
          console.log(`  - Deletando clã inteiro ${clanDoc.id} pois o líder era órfão.`);
          await db.collection("clans").doc(clanDoc.id).delete();
        } else {
          // Remover da array
          await db.collection("clans").doc(clanDoc.id).update({
            members: admin.firestore.FieldValue.arrayRemove(uid),
            memberCount: admin.firestore.FieldValue.increment(-1)
          });
          console.log(`  - Removido do clã ${clanDoc.id}`);
        }
      }

      // 4. Remover de rankings
      const rankingsWeekly = await db.collection("rankings").doc("weekly").listCollections();
      for (const weekColl of rankingsWeekly) {
        const rankingDoc = await weekColl.doc(uid).get();
        if (rankingDoc.exists) {
          await weekColl.doc(uid).delete();
          console.log(`  - Removido do ranking ${weekColl.id}`);
        }
      }

      // 5. Excluir transações e pedidos
      const txSnap = await db.collection("transactions").where("userId", "==", uid).get();
      if (txSnap.size > 0) {
        const batch = db.batch();
        txSnap.forEach(d => batch.delete(d.ref));
        await batch.commit();
        console.log(`  - Deletadas ${txSnap.size} transações`);
      }

      const orderSnap = await db.collection("orders").where("uid", "==", uid).get();
      if (orderSnap.size > 0) {
        const batch = db.batch();
        orderSnap.forEach(d => batch.delete(d.ref));
        await batch.commit();
        console.log(`  - Deletados ${orderSnap.size} pedidos`);
      }
    }
    
    console.log("\n=== LIMPEZA CONCLUÍDA COM SUCESSO ===");

  } catch (error) {
    console.error("Erro durante a execução:", error);
  }
}

run();
