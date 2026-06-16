require('dotenv').config({ path: '../.env' });
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { GoogleGenerativeAI } = require('@google/genai');
const crypto = require('crypto');

// Inicializa o Firebase (assumindo GOOGLE_APPLICATION_CREDENTIALS ou credenciais padrão do ADC)
initializeApp();
const db = getFirestore('default');

const ai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

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
    const prompt = PROMPT_TEMPLATE.replace('{LANG}', targetLang === 'en' ? 'Inglês' : 'Espanhol').replace('{JSON_CONTENT}', JSON.stringify(textObj, null, 2));
    const model = ai.getGenerativeModel({ model: "gemini-1.5-pro" });
    const result = await model.generateContent(prompt);
    let text = result.response.text().trim();
    
    // Tenta limpar possível markdown de código do LLM
    if (text.startsWith('\`\`\`json')) {
        text = text.replace(/^\`\`\`json/, '').replace(/\`\`\`$/, '');
    }
    
    return JSON.parse(text);
}

// Configuração de campos traduzíveis por coleção
const SCHEMA = {
    categories: ['title', 'subtitle', 'description'],
    modules: ['title', 'subtitle', 'moduleSubtitle'],
    trails: ['title', 'subtitle', 'description'],
    lessons: ['title', 'subtitle', 'content'],
    questions: ['statement', 'explanation', 'textWithBlanks', 'normReference'], // options tratadas à parte se necessário
    ebooks: ['ebookTitle', 'ebookSubtitle']
};

async function processCollection(collectionPath, fieldsToTranslate) {
    console.log(\`Processando \${collectionPath}...\`);
    const snap = await db.collection(collectionPath).get();
    
    for (const doc of snap.docs) {
        const data = doc.data();
        let toTranslate = {};
        let hasTranslateableData = false;
        
        for (const field of fieldsToTranslate) {
            if (data[field]) {
                toTranslate[field] = data[field];
                hasTranslateableData = true;
            }
        }
        
        // Trata subcampos especiais (ex: options da Questão)
        if (collectionPath.includes('questions') && data.options) {
            toTranslate.options = data.options;
        }

        if (!hasTranslateableData) continue;

        const currentHash = computeHash(toTranslate);
        let translations = data.translations || {};
        let needsUpdate = false;
        
        for (const lang of ['en', 'es']) {
            if (!translations[lang] || translations[lang]._hash !== currentHash) {
                console.log(\`[ \${lang.toUpperCase()} ] Traduzindo doc: \${doc.id}...\`);
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
    
    // Exemplo de pipeline. O banco é estruturado com subcoleções.
    // categories/{cat}/modules/{mod}/trails/{trail}/lessons/{les}
    
    const categories = await db.collection('categories').get();
    for (const cat of categories.docs) {
        await processCollection(\`categories\`, SCHEMA.categories);
        
        const modules = await db.collection(\`categories/\${cat.id}/modules\`).get();
        for (const mod of modules.docs) {
            await processCollection(\`categories/\${cat.id}/modules\`, SCHEMA.modules);
            
            const trails = await db.collection(\`categories/\${cat.id}/modules/\${mod.id}/trails\`).get();
            for (const trail of trails.docs) {
                await processCollection(\`categories/\${cat.id}/modules/\${mod.id}/trails\`, SCHEMA.trails);
                
                // Lições
                await processCollection(\`categories/\${cat.id}/modules/\${mod.id}/trails/\${trail.id}/lessons\`, SCHEMA.lessons);
                
                // Questões e Ebooks seriam similares iterando nas subcoleções apropriadas
            }
        }
    }
    
    console.log("=== PIPELINE FINALIZADO ===");
}

run().catch(console.error);
