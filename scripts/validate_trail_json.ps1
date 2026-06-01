# Valida estrutura do JSON gerado pelo NotebookLM antes de salvar como trilha
# Uso: .\scripts\validate_trail_json.ps1 -Path "caminho\para\trilha.json"

param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path $Path)) {
  Write-Host "ERRO: Arquivo nao encontrado: $Path" -ForegroundColor Red
  exit 1
}

$enc = [System.Text.Encoding]::UTF8
$raw = [System.IO.File]::ReadAllText($Path, $enc)

try {
  $json = $raw | ConvertFrom-Json
} catch {
  Write-Host "ERRO: JSON invalido: $_" -ForegroundColor Red
  exit 1
}

$errors = @()
$warnings = @()

# Campos obrigatorios no topo
$required = @('category', 'categorySubtitle', 'categoryOrder', 'module', 'moduleSubtitle', 'moduleOrder', 'trail', 'trailOrder', 'questions')
foreach ($field in $required) {
  if (-not $json.PSObject.Properties[$field]) {
    $errors += "Campo obrigatorio ausente: $field"
  }
}

# Validar questoes
if ($json.questions) {
  $total = $json.questions.Count
  Write-Host ""
  Write-Host "Total de questoes: $total" -ForegroundColor Cyan

  $byType = @{ multipleChoice = 0; trueFalse = 0; fillBlank = 0 }
  $byDiff = @{ easy = 0; medium = 0; hard = 0 }

  for ($i = 0; $i -lt $total; $i++) {
    $q = $json.questions[$i]
    $qNum = $i + 1

    # Tipo
    if ($q.type -notin @('multipleChoice', 'trueFalse', 'fillBlank')) {
      $errors += "Questao $qNum : tipo invalido '$($q.type)'"
    } else {
      $byType[$q.type]++
    }

    # Dificuldade
    if ($q.difficulty -notin @('easy', 'medium', 'hard')) {
      $errors += "Questao $qNum : dificuldade invalida '$($q.difficulty)'"
    } else {
      $byDiff[$q.difficulty]++
    }

    # Campos especificos por tipo
    if ($q.type -eq 'multipleChoice') {
      if (-not $q.options -or $q.options.Count -ne 4) {
        $errors += "Questao $qNum : multipleChoice deve ter exatamente 4 opcoes"
      }
      if ($null -eq $q.correctIndex -or $q.correctIndex -lt 0 -or $q.correctIndex -gt 3) {
        $errors += "Questao $qNum : correctIndex invalido (deve ser 0-3)"
      }
    }
    if ($q.type -eq 'trueFalse') {
      if ($null -eq $q.correctAnswer) {
        $errors += "Questao $qNum : trueFalse deve ter correctAnswer booleano"
      }
    }
    if ($q.type -eq 'fillBlank') {
      if (-not $q.blanks -or $q.blanks.Count -lt 1) {
        $errors += "Questao $qNum : fillBlank deve ter ao menos 1 blank"
      }
    }

    # Statement e explanation
    if (-not $q.statement) { $errors += "Questao $qNum : statement vazio" }
    if (-not $q.explanation) { $errors += "Questao $qNum : explanation vazio" }
  }

  Write-Host ""
  Write-Host "Distribuicao por tipo:" -ForegroundColor Cyan
  Write-Host "  multipleChoice: $($byType.multipleChoice) (esperado: 10)"
  Write-Host "  trueFalse:      $($byType.trueFalse) (esperado: 5)"
  Write-Host "  fillBlank:      $($byType.fillBlank) (esperado: 3)"

  Write-Host ""
  Write-Host "Distribuicao por dificuldade:" -ForegroundColor Cyan
  Write-Host "  easy:   $($byDiff.easy) (esperado: 6)"
  Write-Host "  medium: $($byDiff.medium) (esperado: 8)"
  Write-Host "  hard:   $($byDiff.hard) (esperado: 4)"

  if ($total -ne 18) {
    $warnings += "Total de questoes e $total, esperado 18"
  }
  if ($byType.multipleChoice -ne 10) { $warnings += "Esperado 10 multipleChoice" }
  if ($byType.trueFalse -ne 5) { $warnings += "Esperado 5 trueFalse" }
  if ($byType.fillBlank -ne 3) { $warnings += "Esperado 3 fillBlank" }
}

Write-Host ""
if ($errors.Count -gt 0) {
  Write-Host "ERROS ($($errors.Count)):" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}
if ($warnings.Count -gt 0) {
  Write-Host "AVISOS ($($warnings.Count)):" -ForegroundColor Yellow
  $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
  Write-Host "JSON valido!" -ForegroundColor Green
}
