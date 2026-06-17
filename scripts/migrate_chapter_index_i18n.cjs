// Copia as traduções de título dos capítulos (subcoleção `chapters`, já
// traduzida) para o array `chapterIndex` embutido no doc do ebook — assim o
// sumário (TOC) mostra os nomes traduzidos. SEM Gemini: só lê/escreve Firestore.
// Uso: node migrate_chapter_index_i18n.cjs [--apply]
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'spark-v1-e0eb5' });
const db = admin.firestore();
db.settings({ databaseId: 'default' });

const APPLY = process.argv.includes('--apply');

(async () => {
  const ebs = await db.collectionGroup('ebooks').get();
  let ebooksChanged = 0, entriesChanged = 0, ebooksScanned = 0;
  for (const eb of ebs.docs) {
    ebooksScanned++;
    const d = eb.data();
    const ci = Array.isArray(d.chapterIndex) ? d.chapterIndex : [];
    if (ci.length === 0) continue;

    const chs = await eb.ref.collection('chapters').get();
    // mapa por id e por order
    const byId = {}, byOrder = {};
    chs.forEach(c => {
      const cd = c.data();
      if (cd.translations) { byId[c.id] = cd.translations; byOrder[cd.order] = cd.translations; }
    });
    if (Object.keys(byId).length === 0 && Object.keys(byOrder).length === 0) continue;

    let changed = false;
    const newCi = ci.map((entry, idx) => {
      const tr = byId[entry.id] || byOrder[entry.order] || byOrder[idx] || byOrder[idx + 1];
      if (!tr) return entry;
      // monta translations só com 'title' (e subtitle se existir) por idioma
      const langs = {};
      for (const [lang, fields] of Object.entries(tr)) {
        if (fields && typeof fields === 'object' && fields.title) {
          langs[lang] = { title: fields.title };
        }
      }
      if (Object.keys(langs).length === 0) return entry;
      // se já idêntico, não conta
      const existing = JSON.stringify(entry.translations || {});
      if (existing === JSON.stringify(langs)) return entry;
      changed = true; entriesChanged++;
      return { ...entry, translations: langs };
    });

    if (changed) {
      ebooksChanged++;
      if (APPLY) await eb.ref.update({ chapterIndex: newCi });
    }
  }
  console.log(`${APPLY ? 'APLICADO' : 'DRY-RUN'}: ebooks escaneados=${ebooksScanned}, ebooks a alterar=${ebooksChanged}, entradas de capítulo a traduzir=${entriesChanged}`);
  process.exit(0);
})().catch(e => { console.error('ERRO:', e.message); process.exit(1); });
