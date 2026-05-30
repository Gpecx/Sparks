# validate_ebook_json.ps1
# Valida um arquivo JSON de e-book do SPARK.
# Uso: powershell -File scripts/validate_ebook_json.ps1 -Path "content/seed/cat01_instalacoes/mod01_gestao_riscos/ebook_nr06.json"

param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

$errors = @()
$warnings = @()

# ── 1. Arquivo existe e é JSON válido ────────────────────────────
if (-not (Test-Path $Path)) {
  Write-Error "Arquivo não encontrado: $Path"
  exit 1
}

try {
  $json = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  Write-Error "JSON inválido: $_"
  exit 1
}

# ── 2. Campos obrigatórios de cabeçalho ──────────────────────────
$required = @('category','categoryOrder','module','moduleOrder','ebookTitle','ebookSubtitle','estimatedMinutes','sections')
foreach ($field in $required) {
  if ($null -eq $json.$field) {
    $errors += "Campo obrigatório ausente: '$field'"
  }
}

# ── 3. Seções ────────────────────────────────────────────────────
$sections = $json.sections
if ($sections -and $sections.Count -gt 0) {
  $validTypes = @('text','list','note','formula','summary')
  $ids = @()

  foreach ($s in $sections) {
    if (-not $s.id)    { $errors += "Seção sem 'id'" }
    if (-not $s.title) { $errors += "Seção '$($s.id)' sem 'title'" }
    if (-not $s.type)  { $errors += "Seção '$($s.id)' sem 'type'" }
    elseif ($s.type -notin $validTypes) {
      $errors += "Seção '$($s.id)': tipo inválido '$($s.type)'. Válidos: $($validTypes -join ', ')"
    }

    # validações por tipo
    switch ($s.type) {
      'text'    { if (-not $s.body)    { $warnings += "Seção '$($s.id)' (text) sem 'body'" } }
      'list'    { if (-not $s.items -or $s.items.Count -eq 0) { $errors += "Seção '$($s.id)' (list) sem itens" } }
      'note'    { if (-not $s.body)    { $warnings += "Seção '$($s.id)' (note) sem 'body'" } }
      'formula' { if (-not $s.formula) { $errors += "Seção '$($s.id)' (formula) sem 'formula'" } }
      'summary' { if (-not $s.body)    { $warnings += "Seção '$($s.id)' (summary) sem 'body'" } }
    }

    # IDs únicos
    if ($s.id -in $ids) { $errors += "ID de seção duplicado: '$($s.id)'" }
    $ids += $s.id
  }

  # Contagem mínima
  if ($sections.Count -lt 4) {
    $warnings += "Poucas seções ($($sections.Count)). Recomendado: 4-8"
  }

  # Deve terminar com summary
  $lastType = $sections[-1].type
  if ($lastType -ne 'summary') {
    $warnings += "Última seção é '$lastType'. Recomendado terminar com 'summary'"
  }
} else {
  $errors += "Campo 'sections' está vazio ou ausente"
}

# ── 4. estimatedMinutes ──────────────────────────────────────────
if ($json.estimatedMinutes -and ($json.estimatedMinutes -lt 5 -or $json.estimatedMinutes -gt 120)) {
  $warnings += "estimatedMinutes=$($json.estimatedMinutes) fora do intervalo esperado (5-120)"
}

# ── 5. Relatório ─────────────────────────────────────────────────
$file = Split-Path $Path -Leaf
Write-Host ""
Write-Host "=== Validação E-book: $file ===" -ForegroundColor Cyan
Write-Host "  Título  : $($json.ebookTitle)"
Write-Host "  Módulo  : $($json.module)"
Write-Host "  Seções  : $($sections.Count)  |  Tempo: $($json.estimatedMinutes) min"
Write-Host ""

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
  Write-Host "  [OK] VALIDO -- nenhum problema encontrado." -ForegroundColor Green
} else {
  foreach ($e in $errors)   { Write-Host "  [ERRO]  $e"   -ForegroundColor Red }
  foreach ($w in $warnings) { Write-Host "  [AVISO] $w"   -ForegroundColor Yellow }
}
Write-Host ""

if ($errors.Count -gt 0) { exit 1 } else { exit 0 }
