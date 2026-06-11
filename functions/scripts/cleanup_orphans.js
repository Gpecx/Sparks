/**
 * Limpeza de órfãos no Firestore — alinhada ao modelo de dados real do app.
 *
 * Remove dados que ficaram "presos" após exclusões de conta/clã antigas,
 * inclusive nomes que ainda aparecem no ranking (ex.: usuário "davi") e
 * clãs que não existem mais mas continuam listados.
 *
 * Trata TRÊS fontes de órfãos de forma independente:
 *   1. users/{uid} cujo uid não existe mais no Firebase Auth
 *   2. entradas de ranking (rankings/weekly/{semana}/{uid}) sem usuário válido
 *      → pega o "davi" mesmo que o doc users/ dele já tenha sumido
 *   3. clãs (clans/{id}) sem nenhum membro válido (subcoleção members vazia
 *      ou só com membros que não existem mais no Auth)
 *
 * Uso (dentro de functions/, com credenciais de admin disponíveis):
 *   node scripts/cleanup_orphans.js --dry-run   # apenas relata
 *   node scripts/cleanup_orphans.js             # apaga de verdade
 *
 * Requer Application Default Credentials apontando para o projeto, ex.:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/caminho/serviceAccount.json
 */

const admin = require("firebase-admin");

admin.initializeApp({ projectId: "spark-v1-e0eb5" });

const db = admin.firestore("default");
const auth = admin.auth();

const DRY_RUN = process.argv.includes("--dry-run");

async function getAuthUids() {
  const uids = new Set();
  let pageToken;
  do {
    const res = await auth.listUsers(1000, pageToken);
    res.users.forEach((u) => uids.add(u.uid));
    pageToken = res.pageToken;
  } while (pageToken);
  return uids;
}

async function del(ref, label) {
  if (DRY_RUN) {
    console.log(`  [DRY] apagaria ${label}`);
    return;
  }
  await db.recursiveDelete(ref);
  console.log(`  - apagado ${label}`);
}

async function run() {
  console.log(`Iniciando limpeza de órfãos${DRY_RUN ? " (DRY RUN)" : ""}...`);

  const authUids = await getAuthUids();
  console.log(`Firebase Auth: ${authUids.size} usuários válidos.`);

  // ── 1. Usuários órfãos (doc users/ sem conta no Auth) ────────────
  const usersSnap = await db.collection("users").get();
  const orphanUsers = usersSnap.docs.filter((d) => !authUids.has(d.id));
  console.log(`\n[1] users órfãos: ${orphanUsers.length}`);
  for (const doc of orphanUsers) {
    console.log(`UID órfão: ${doc.id}`);
    await del(doc.ref, `users/${doc.id}`);
    await del(db.collection("public_profiles").doc(doc.id), `public_profiles/${doc.id}`);
  }

  // ── 2. Entradas de ranking sem usuário válido ────────────────────
  //    Pega nomes que continuam no ranking mesmo sem doc users/ (ex.: davi)
  const weekCols = await db.collection("rankings").doc("weekly").listCollections();
  console.log(`\n[2] varrendo ${weekCols.length} semana(s) de ranking...`);
  let orphanRankings = 0;
  for (const col of weekCols) {
    const entries = await col.get();
    for (const entry of entries.docs) {
      // doc.id é o uid do jogador
      if (!authUids.has(entry.id)) {
        const name = entry.data().displayName || "(sem nome)";
        console.log(`Entrada de ranking órfã: ${col.id}/${entry.id} (${name})`);
        if (DRY_RUN) {
          console.log(`  [DRY] apagaria rankings/weekly/${col.id}/${entry.id}`);
        } else {
          await entry.ref.delete();
          console.log(`  - apagado rankings/weekly/${col.id}/${entry.id}`);
        }
        orphanRankings++;
      }
    }
  }
  console.log(`[2] entradas de ranking órfãs: ${orphanRankings}`);

  // ── 3. Clãs fantasmas (sem nenhum membro válido) ─────────────────
  const clansSnap = await db.collection("clans").get();
  console.log(`\n[3] verificando ${clansSnap.size} clã(s)...`);
  let ghostClans = 0;
  for (const clan of clansSnap.docs) {
    const membersSnap = await clan.ref.collection("members").get();
    const validMembers = membersSnap.docs.filter((m) => authUids.has(m.id));
    if (validMembers.length === 0) {
      const clanName = clan.data().name || "(sem nome)";
      console.log(
        `Clã fantasma: ${clan.id} ("${clanName}") — ${membersSnap.size} membro(s), 0 válido(s)`
      );
      await del(clan.ref, `clans/${clan.id}`);
      ghostClans++;
    }
  }
  console.log(`[3] clãs fantasmas removidos: ${ghostClans}`);

  console.log(`\n=== LIMPEZA ${DRY_RUN ? "(DRY RUN) " : ""}CONCLUÍDA ===`);
}

run().catch((e) => {
  console.error("Erro durante a execução:", e);
  process.exit(1);
});
