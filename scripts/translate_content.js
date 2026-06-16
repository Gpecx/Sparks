require('dotenv').config({ path: '../.env' });
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { GoogleGenAI } = require('@google/genai');
const crypto = require('crypto');

// Inicializa o Firebase
initializeApp({ projectId: 'spark-v1-e0eb5' });
const db = getFirestore('default');

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const GLOSSARY = `
- Nomes de normas técnicas ("NR-10", "NR-35", "IEC 61850", "SPDA", "NBR", etc.) DEVEM permanecer intactos.
- Fórmulas, símbolos matemáticos e unidades (V, A, kV, mA, W, etc.) NÃO devem ser traduzidos.
- Use terminologia padrão de engenharia elétrica do idioma alvo.
`;

const PROMPT_TEMPLATE = `
Você é um engenheiro eletricista sênior traduzindo conteúdo educacional do Português para o {LANG}.
Traduza apenas os valores string do JSON abaixo. Mantenha as chaves originais intactas.
Preserve qualquer formatação Markdown e referências a placeholders.

Regras Estritas:
${GLOSSARY}

JSON original:
{JSON_CONTENT}

Responda APENAS com o JSON traduzido. Nada de formatação extra ou markdown ao redor.
`;

function computeHash(obj) {
    return crypto.createHash('md5').update(JSON.stringify(obj)).digest('hex');
}

async function translateObject(textObj, targetLang) {
    const prompt = PROMPT_TEMPLATE
        .replace('{LANG}', targetLang === 'en' ? 'Inglês' : 'Espanhol')
        .replace('{JSON_CONTENT}', JSON.stringify(textObj, null, 2));
    
    const result = await ai.models.generateContent({
        model: 'gemini-2.5-pro',
        contents: prompt
    });
    
    let text = result.text.trim();
    if (text.startsWith('\`\`\`json')) {
        text = text.replace(/^\`\`\`json/, '').replace(/\`\`\`$/, '');
    } else if (text.startsWith('\`\`\`')) {
        text = text.replace(/^\`\`\`/, '').replace(/\`\`\`$/, '');
    }
    
    return JSON.parse(text);
}

// Configuração de campos traduzíveis
const SCHEMA = {
    categories: ['title', 'subtitle', 'description'],
    modules: ['title', 'subtitle', 'moduleSubtitle'],
    trails: ['title', 'subtitle', 'description'],
    lessons: ['title', 'subtitle', 'content'],
    questions: ['statement', 'explanation', 'textWithBlanks', 'normReference', 'options'],
    ebooks: ['title', 'subtitle'],
    chapters: ['title', 'subtitle', 'sections']
};

async function processCollectionGroup(collectionId, fieldsToTranslate) {
    console.log(\`Buscando collectionGroup: \${collectionId}...\`);
    const snap = await db.collectionGroup(collectionId).get();
    console.log(\`Encontrados \${snap.docs.length} documentos em \${collectionId}\`);
    
    for (const doc of snap.docs) {
        const data = doc.data();
        let toTranslate = {};
        let hasTranslateableData = false;
        
        for (const field of fieldsToTranslate) {
            if (field === 'options' && Array.isArray(data.options)) {
                toTranslate.options = data.options;
                hasTranslateableData = true;
            } else if (field === 'sections' && Array.isArray(data.sections)) {
                // Preservar formulas enviando apenas o que é texto
                toTranslate.sections = data.sections.map(sec => ({
                    title: sec.title,
                    body: sec.body,
                    explanation: sec.explanation,
                    items: sec.items
                }));
                hasTranslateableData = true;
            } else if (data[field]) {
                toTranslate[field] = data[field];
                hasTranslateableData = true;
            }
        }

        // Tratar subcampos como blanks[].answer para questões
        if (collectionId === 'questions' && data.blanks && Array.isArray(data.blanks)) {
            toTranslate.blanks = data.blanks.map(b => ({ answer: b.answer }));
            hasTranslateableData = true;
        }

        if (!hasTranslateableData) continue;

        const currentHash = computeHash(toTranslate);
        let translations = data.translations || {};
        let needsUpdate = false;
        
        for (const lang of ['en', 'es']) {
            if (!translations[lang] || translations[lang]._hash !== currentHash) {
                console.log(\`[ \${lang.toUpperCase()} ] Traduzindo \${collectionId} doc: \${doc.id}...\`);
                try {
                    const translated = await translateObject(toTranslate, lang);
                    translations[lang] = { ...translated, _hash: currentHash };
                    needsUpdate = true;
                } catch (e) {
                    console.error(\`Falha ao traduzir \${doc.id} para \${lang}:\`, e.message);
                }
            }
        }
        
        if (needsUpdate) {
            await doc.ref.update({ translations });
            console.log(\`[ OK ] Atualizado: \${doc.id}\`);
        }
    }
}

async function run() {
    console.log("=== INICIANDO PIPELINE DE TRADUÇÃO I18N ===");
    
    const collectionsToProcess = [
        { id: 'categories', schema: SCHEMA.categories },
        { id: 'modules', schema: SCHEMA.modules },
        { id: 'trails', schema: SCHEMA.trails },
        { id: 'lessons', schema: SCHEMA.lessons },
        { id: 'questions', schema: SCHEMA.questions },
        { id: 'ebooks', schema: SCHEMA.ebooks },
        { id: 'chapters', schema: SCHEMA.chapters }
    ];

    for (const coll of collectionsToProcess) {
        await processCollectionGroup(coll.id, coll.schema);
    }
    
    console.log("=== PIPELINE FINALIZADO ===");
}

run().catch(console.error);
