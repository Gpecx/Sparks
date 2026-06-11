# Como rodar o SPARK para visualizar

> Tudo roda **localmente no seu PC** — nada é exposto na internet.

## Jeito mais rápido (Chrome / web)

Na raiz do projeto, no PowerShell:

```powershell
.\scripts\run_app.ps1
```

Isso roda `flutter pub get` e abre o app no Chrome com **hot reload**
(salvou um arquivo → recarrega na hora). Para parar, tecle `q` no terminal.

## Como app desktop (janela Windows)

```powershell
.\scripts\run_app.ps1 -Windows
```

## O que olhar nesta rodada

Branch atual: **`feature/edicao-trilhas`**. As novidades estão na aba
**FERRAMENTAS** (22 ferramentas). Para conferir o trabalho recente:

| Ferramenta | Onde ver | O que testar |
|-----------|----------|--------------|
| **Tensão pu — Base ONS × TP** | Conversões & Análise | pu 1,05 / base 230 / TP 245-115 → ~113,36 V (e o "erro ingênuo" 120,75 V) |
| **Qualidade de Energia** | Qualidade de Energia | aba Desequilíbrio → PRODIST vs aproximada |
| **Cabos de Rede (RJ-45)** | Redes & Comunicação | pinagem T568A/B + conector desenhado |
| **Arc Flash** | Aterramento & Segurança | 480 V, 25 kA, 0,1 s, 455 mm → energia + categoria de EPI |
| **Corrente Nominal → aba "Inrush banco"** | Equipamentos | adicionar 2-3 trafos, informar ajuste 50 → verdito de margem |
| **Curvas 51 → modo "Comparar curvas"** | Proteção (Relés) | 2 relés, mesma corrente de falta → checagem de CTI no gráfico |

## Se der algum erro de build

```powershell
flutter doctor        # diagnostica o ambiente
flutter clean         # limpa cache de build
flutter pub get       # rebaixa dependencias
```

## Testes (opcional, valida a lógica sem abrir a tela)

```powershell
flutter test test\tools\
```
Esperado: **90/90 passando**.
