/**
 * Reset de ELO de TODOS os usuários para 0 (patente Iron III).
 *
 * Zera `eloRating` de todo doc em users/ e limpa qualquer cooldown/contador
 * de abandono pendente. O espelho public_profiles/{uid} é atualizado
 * automaticamente pelo trigger `syncPublicProfile` (eloRating é campo público),
 * então o ranking/perfil refletem o reset sem precisar tocar public_profiles
 * aqui.
 *
 * NÃO mexe em wins/losses/totalDuels (histórico do jogador é preservado);
 * apenas o rating que define a patente volta a zero.
 *
 * Uso (dentro de functions/, com credenciais de admin disponíveis):
 *   node scripts/reset_elo.js --dry-run   # apenas relata quantos mudariam
 *   node scripts/reset_elo.js             # aplica de verdade
 *
 * Requer Application Default Credentials apontando para o projeto, ex.:
 *   gcloud auth application-default login
 *   # ou
 *   export GOOGLE_APPLICATION_CREDENTIALS=/caminho/serviceAccount.json
 */

const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");

admin.initializeApp({ projectId: "spark-v1-e0eb5" });

// Banco Firestore NOMEADO ("default"), não o "(default)" — mesmo padrão do index.ts.
const db = getFirestore("default");

const DRY_RUN = process.argv.includes("--dry-run");
const BATCH_SIZE = 400;

async function run() {
  console.log(`Reset de ELO → 0${DRY_RUN ? " (DRY RUN)" : ""}...`);

  const usersSnap = await db.collection("users").get();
  console.log(`Total de usuários: ${usersSnap.size}`);

  // Só conta/atualiza quem ainda não está em 0 (evita escrita à toa).
  const toReset = usersSnap.docs.filter(
    (d) => ((d.get("eloRating")) ?? 0) !== 0
  );
  console.log(`Com ELO ≠ 0 (serão resetados): ${toReset.length}`);

  if (DRY_RUN) {
    for (const d of toReset) {
      console.log(`  [DRY] ${d.id}: eloRating ${d.get("eloRating")} → 0`);
    }
    console.log("\n=== DRY RUN — nada foi alterado ===");
    return;
  }

  let done = 0;
  for (let i = 0; i < toReset.length; i += BATCH_SIZE) {
    const slice = toReset.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const d of slice) {
      batch.update(d.ref, {
        eloRating: 0,
        duelAbandons: 0,
        duelCooldownUntil: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    done += slice.length;
    console.log(`  - resetados ${done}/${toReset.length}`);
  }

  console.log(`\n=== RESET CONCLUÍDO — ${done} usuário(s) em ELO 0 (Iron III) ===`);
}

run().catch((e) => {
  console.error("Erro durante a execução:", e);
  process.exit(1);
});
