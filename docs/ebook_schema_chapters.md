# Schema de E-book SPARK — Formato em Capítulos

E-books longos (~40 páginas) são estruturados em **capítulos**. Cada capítulo
tem suas próprias seções. No app, o documento do e-book guarda só os metadados
+ o índice de capítulos; cada capítulo é carregado sob demanda.

## Estrutura do JSON

```json
{
  "category": "Proteção de Sistemas Elétricos",
  "categorySubtitle": "...",
  "categoryOrder": 5,
  "module": "Fundamentos de Proteção",
  "moduleSubtitle": "...",
  "moduleOrder": 0,
  "ebookTitle": "Fundamentos de Proteção de Sistemas Elétricos",
  "ebookSubtitle": "...",
  "estimatedMinutes": 90,
  "trailFiles": ["t01_....json", "t02_....json"],
  "chapters": [
    {
      "id": "c01",
      "order": 0,
      "title": "Capítulo 1 — Por que proteger?",
      "subtitle": "Motivação e contexto histórico",
      "estimatedMinutes": 12,
      "sections": [
        { "id": "s1", "title": "...", "type": "text", "body": "..." },
        { "id": "s2", "title": "...", "type": "list", "items": ["...","..."] },
        { "id": "s3", "title": "...", "type": "note", "body": "..." },
        { "id": "s4", "title": "...", "type": "formula", "formula": "...", "explanation": "..." },
        { "id": "s5", "title": "Resumo do capítulo", "type": "summary", "body": "..." }
      ]
    }
    // ... mais capítulos
  ]
}
```

## Regras de validação (validate_ebook_json.ps1)

- Cabeçalho obrigatório: category, categoryOrder, module, moduleOrder,
  ebookTitle, ebookSubtitle, estimatedMinutes, chapters
- 5 a 12 capítulos recomendados (para ~40 páginas)
- Cada capítulo: title + sections (>= 3 seções)
- Cada seção: id, title, type (text|list|note|formula|summary)
- list exige items; formula exige formula
- Recomendado: cada capítulo termina com seção type "summary"
- IDs de capítulo e de seção únicos

## Importação

O `id`/`order` do capítulo podem ser omitidos no JSON — o importador do admin
gera automaticamente (`c01`, `c02`...) na ordem do array. Se informados, são
respeitados.

## Compatibilidade legada

O importador ainda aceita o formato antigo (campo `sections` na raiz, sem
`chapters`) — nesse caso o e-book vira um único capítulo. Os 9 e-books v1 já
importados continuam funcionando.
