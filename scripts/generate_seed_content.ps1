# SPARK - Gerador de Seed de Conteudo
# Le taxonomy.json (UTF-8) e gera um arquivo JSON por trilha em content\seed\
# Uso: .\scripts\generate_seed_content.ps1

$enc       = [System.Text.Encoding]::UTF8
$taxPath   = Join-Path $PSScriptRoot "taxonomy.json"
$outputRoot = Join-Path $PSScriptRoot "..\content\seed"

# Le o JSON de taxonomia em UTF-8
$raw      = [System.IO.File]::ReadAllText($taxPath, $enc)
$taxonomy = $raw | ConvertFrom-Json

$created = 0
$catIndex = 0

foreach ($cat in $taxonomy) {
  $catPath = Join-Path $outputRoot $cat.folder
  New-Item -ItemType Directory -Force -Path $catPath | Out-Null

  $modIndex = 0
  foreach ($mod in $cat.modules) {
    $modPath = Join-Path $catPath $mod.folder
    New-Item -ItemType Directory -Force -Path $modPath | Out-Null

    $trailIndex = 0
    foreach ($trail in $mod.trails) {

      # Nome de arquivo seguro (ASCII)
      $safe = $trail -replace '[^\w\s-]', '' -replace '\s+', '_'
      $safe = $safe.ToLower()
      if ($safe.Length -gt 50) { $safe = $safe.Substring(0, 50) }
      $fileName = "t{0:D2}_{1}.json" -f ($trailIndex + 1), $safe
      $filePath = Join-Path $modPath $fileName

      # Objeto JSON
      $obj = [ordered]@{
        category          = $cat.category
        categorySubtitle  = $cat.categorySubtitle
        categoryOrder     = $catIndex
        module            = $mod.module
        moduleSubtitle    = $mod.moduleSubtitle
        moduleOrder       = $modIndex
        trail             = $trail
        trailOrder        = $trailIndex
        questions = @(
          [ordered]@{
            type         = "multipleChoice"
            statement    = "[PLACEHOLDER] Trilha: $trail - conteudo em elaboracao no NotebookLM."
            options      = @(
              "Opcao A - em elaboracao",
              "Opcao B - em elaboracao",
              "Opcao C - em elaboracao",
              "Opcao D - em elaboracao"
            )
            correctIndex = 0
            explanation  = "Questao provisoria. Sera substituida pelo conteudo definitivo apos importacao do NotebookLM."
            difficulty   = "medium"
          }
        )
      }

      $json = $obj | ConvertTo-Json -Depth 10
      [System.IO.File]::WriteAllText($filePath, $json, $enc)

      $created++
      $trailIndex++
    }
    $modIndex++
  }
  $catIndex++
}

# Gera all_trails.json (array com todos os objetos — usado para bulk import no admin panel)
$allTrails = [System.Collections.Generic.List[object]]::new()

$catIdx = 0
foreach ($cat in $taxonomy) {
  $modIdx = 0
  foreach ($mod in $cat.modules) {
    $tIdx = 0
    foreach ($trail in $mod.trails) {
      $allTrails.Add([ordered]@{
        category         = $cat.category
        categorySubtitle = $cat.categorySubtitle
        categoryOrder    = $catIdx
        module           = $mod.module
        moduleSubtitle   = $mod.moduleSubtitle
        moduleOrder      = $modIdx
        trail            = $trail
        trailOrder       = $tIdx
        questions        = @(
          [ordered]@{
            type         = "multipleChoice"
            statement    = "[PLACEHOLDER] Trilha: $trail - conteudo em elaboracao no NotebookLM."
            options      = @(
              "Opcao A - em elaboracao",
              "Opcao B - em elaboracao",
              "Opcao C - em elaboracao",
              "Opcao D - em elaboracao"
            )
            correctIndex = 0
            explanation  = "Questao provisoria. Sera substituida pelo conteudo definitivo apos importacao do NotebookLM."
            difficulty   = "medium"
          }
        )
      })
      $tIdx++
    }
    $modIdx++
  }
  $catIdx++
}

$allJson = $allTrails | ConvertTo-Json -Depth 10
$allPath = Join-Path $outputRoot "all_trails.json"
[System.IO.File]::WriteAllText($allPath, $allJson, $enc)

Write-Host ""
Write-Host "Seed gerado com sucesso!" -ForegroundColor Green
Write-Host "  Arquivos individuais : $created"
Write-Host "  all_trails.json      : $($allTrails.Count) trilhas"
Write-Host "  Local                : $outputRoot"
Write-Host ""
