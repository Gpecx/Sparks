// Gera vouchers de cortesia direto no Firestore (mesmo schema do createAccessCodes).
// Uso: node scripts/gen_vouchers.cjs [quantidade] [dias] ["rótulo"]
const crypto = require('crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sem 0 O 1 I L
function genCode() {
  const bytes = crypto.randomBytes(8);
  let body = '';
  for (let i = 0; i < 8; i++) {
    body += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
    if (i === 3) body += '-';
  }
  return `PROF-${body}`;
}

const COUNT = Number(process.argv[2]) || 3;
const DAYS = Number(process.argv[3]) || 30;
const LABEL = process.argv[4] || 'Professores - teste';

(async () => {
  const app = initializeApp({ projectId: 'spark-v1-e0eb5' });
  const db = getFirestore(app, 'default'); // banco nomeado "default"
  const col = db.collection('access_codes');

  const created = [];
  while (created.length < COUNT) {
    const code = genCode();
    const ref = col.doc(code);
    const snap = await ref.get();
    if (snap.exists) continue; // guard de unicidade: nunca sobrescreve
    await ref.set({
      code,
      durationDays: DAYS,
      active: true,
      maxUses: 1,
      usedCount: 0,
      createdBy: 'admin-script:gpecxdev',
      label: LABEL,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: null,
      redeemedBy: [],
    });
    created.push(code);
  }

  console.log(`\n✅ ${created.length} voucher(s) de ${DAYS} dias (${LABEL}):\n`);
  created.forEach((c) => console.log('   ' + c));
  console.log('');
  process.exit(0);
})().catch((e) => {
  console.error('ERRO:', e.message || e);
  process.exit(1);
});
