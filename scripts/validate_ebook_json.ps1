# validate_ebook_json.ps1
# Valida um arquivo JSON de e-book do SPARK (formato em capitulos).
# Uso: powershell -File scripts/validate_ebook_json.ps1 -Path "content/seed/.../ebook_xxx.json"

param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

$errors = @()
$warnings = @()

# ── 1. Arquivo existe e e JSON valido ────────────────────────────
if (-not (Test-Path $Path)) {
  Write-Error "Arquivo nao encontrado: $Path"
  exit 1
}

try {
  $json = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  Write-Error "JSON invalido: $_"
  exit 1
}

# ── 2. Campos obrigatorios de cabecalho ──────────────────────────
$required = @('category','categoryOrder','module','moduleOrder','ebookTitle','ebookSubtitle','estimatedMinutes','chapters')
foreach ($field in $required) {
  if ($null -eq $json.$field) {
    $errors += "Campo obrigatorio ausente: '$field'"
  }
}

$validTypes = @('text','list','note','formula','summary')

function Test-Sections($sections, $ctx) {
  $script:localErrors = @()
  $ids = @()
  if (-not $sections -or $sections.Count -eq 0) {
    $script:errors += "$ctx sem secoes"
    return
  }
  foreach ($s in $sections) {
    if (-not $s.id)    { $script:errors += "$ctx secao sem 'id'" }
    if (-not $s.title) { $script:errors += "$ctx secao '$($s.id)' sem 'title'" }
    if (-not $s.type)  { $script:errors += "$ctx secao '$($s.id)' sem 'type'" }
    elseif ($s.type -notin $validTypes) {
      $script:errors += "$ctx secao '$($s.id)': tipo invalido '$($s.type)'"
    }
    switch ($s.type) {
      'list'    { if (-not $s.items -or $s.items.Count -eq 0) { $script:errors += "$ctx secao '$($s.id)' (list) sem itens" } }
      'formula' { if (-not $s.formula) { $script:errors += "$ctx secao '$($s.id)' (formula) sem 'formula'" } }
      'text'    { if (-not $s.body)    { $script:warnings += "$ctx secao '$($s.id)' (text) sem 'body'" } }
      'note'    { if (-not $s.body)    { $script:warnings += "$ctx secao '$($s.id)' (note) sem 'body'" } }
      'summary' { if (-not $s.body)    { $script:warnings += "$ctx secao '$($s.id)' (summary) sem 'body'" } }
    }
    if ($s.id -in $ids) { $script:errors += "$ctx id de secao duplicado: '$($s.id)'" }
    $ids += $s.id
  }
}

# ── 3. Capitulos ─────────────────────────────────────────────────
$chapters = $json.chapters
$totalSections = 0
if ($chapters -and $chapters.Count -gt 0) {
  $chIds = @()
  $idx = 0
  foreach ($ch in $chapters) {
    $idx++
    $ctx = "Cap.$idx"
    if (-not $ch.title) { $errors += "$ctx sem 'title'" }
    if ($null -eq $ch.sections) { $errors += "$ctx sem 'sections'" }
    else {
      Test-Sections $ch.sections $ctx
      $totalSections += $ch.sections.Count
      if ($ch.sections.Count -lt 3) { $warnings += "$ctx tem poucas secoes ($($ch.sections.Count)); recomendado >= 3" }
    }
    # ultima secao do capitulo deve ser summary (recomendado)
    if ($ch.sections -and $ch.sections.Count -gt 0 -and $ch.sections[-1].type -ne 'summary') {
      $warnings += "$ctx nao termina com 'summary'"
    }
    if ($ch.id -and ($ch.id -in $chIds)) { $errors += "Id de capitulo duplicado: '$($ch.id)'" }
    if ($ch.id) { $chIds += $ch.id }
  }

  if ($chapters.Count -lt 3) {
    $warnings += "Poucos capitulos ($($chapters.Count)). Para e-book completo recomenda-se 5-12."
  }
} else {
  $errors += "Campo 'chapters' esta vazio ou ausente"
}

# ── 4. Relatorio ─────────────────────────────────────────────────
$file = Split-Path $Path -Leaf
Write-Host ""
Write-Host "=== Validacao E-book: $file ===" -ForegroundColor Cyan
Write-Host "  Titulo    : $($json.ebookTitle)"
Write-Host "  Modulo    : $($json.module)"
Write-Host "  Capitulos : $($chapters.Count)  |  Secoes (total): $totalSections  |  Tempo: $($json.estimatedMinutes) min"
Write-Host ""

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
  Write-Host "  [OK] VALIDO -- nenhum problema encontrado." -ForegroundColor Green
} else {
  foreach ($e in $errors)   { Write-Host "  [ERRO]  $e"   -ForegroundColor Red }
  foreach ($w in $warnings) { Write-Host "  [AVISO] $w"   -ForegroundColor Yellow }
}
Write-Host ""

if ($errors.Count -gt 0) { exit 1 } else { exit 0 }
