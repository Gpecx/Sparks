import 'package:spark_app/models/quiz_models.dart';

// ─────────────────────────────────────────────────────────────────
//  BLOCO 1 — MÓDULO 03: Proteção de Linhas de Transmissão (LT)
//  Proteção de Distância ANSI 21, Zonas, Mho e Quadrilateral
//  16 Lições + 3 Avaliações
// ─────────────────────────────────────────────────────────────────

final List<Lesson> mod03Lessons = [

  Lesson(
    id: 'mod03_l01',
    title: 'Desafios das Linhas de Transmissão',
    subtitle: 'Por que LTs exigem proteções avançadas',
    content: r'''
## Linhas de Transmissão — Ambiente Hostil

As linhas de transmissão se estendem por **longas distâncias** e ficam constantemente expostas a:
- Descargas atmosféricas (raios)
- Contato com galhos e vegetação
- Poluição em isoladores
- Ventos e sobrecargas mecânicas

### Por que não basta um relé de sobrecorrente (51)?

Em longos percursos, a **corrente de curto-circuito varia muito** ao longo da linha:
- Falta perto da subestação: corrente altíssima
- Falta na extremidade remota: corrente bem menor (linha longa tem impedância alta)

Isso dificulta discriminar a localização da falta apenas pela corrente.

### Solução: Proteção de Distância

A proteção de distância **mede a impedância** vista pelo relé, que é proporcional à distância até a falta — independente do nível de geração.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l01_q1',
        statement: 'Por que relés de sobrecorrente simples (ANSI 51) são insuficientes para proteção de longas linhas de transmissão?',
        options: [
          'Porque não suportam altas tensões de transmissão',
          'Porque a corrente de curto varia muito ao longo da linha, dificultando a discriminação por magnitude',
          'Porque não possuem função de reclose automático',
          'Porque só funcionam em redes de baixa tensão',
        ],
        correctIndex: 1,
        explanation: 'Em linhas longas, a corrente de curto-circuito em uma falta distante pode ser próxima à corrente de carga pesada. A proteção de distância soluciona isso medindo impedância, não corrente.',
      ),
      TrueFalse(
        id: 'mod03_l01_q2',
        statement: 'A proteção de distância mede a impedância vista pelo relé, que é proporcional à distância até a falta.',
        isTrue: true,
        explanation: 'Correto. Z = V/I e a impedância de uma linha é proporcional ao comprimento (Z = z × distância). O relé calcula Z e localiza a falta com precisão.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l02',
    title: 'Função ANSI 21 — Proteção de Distância',
    subtitle: 'Princípio de medição de impedância e localização de falta',
    content: r'''
## Como Funciona a Proteção de Distância (ANSI 21)?

O relé de distância **mede continuamente** a razão V/I para calcular a impedância aparente:

$$Z_{aparente} = \\frac{V_{medida}}{I_{medida}}$$

### Princípio de Operação

**Condição normal (sem falta):**
- V é nominal, I é de carga → Z grande (impedância de carga)

**Durante falta:**
- V cai bruscamente, I sobe → Z cai para valor proporcional à distância da falta

$$Z_{falta} = Z_{linha} \\times \\frac{d}{L}$$

Onde:
- $Z_{linha}$ = impedância total da linha
- $d$ = distância da falta a partir do relé
- $L$ = comprimento total da linha

### Por que é superior ao sobrecorrente?

A impedância calculada **independe do nível de geração** do sistema. Mesmo com geração variável (DER, renováveis), o alcance do relé de distância permanece estável.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l02_q1',
        statement: 'O relé de distância (ANSI 21) determina a localização da falta medindo:',
        options: [
          'Apenas a corrente de falta',
          'Apenas a queda de tensão durante a falta',
          'A razão V/I (impedância aparente), proporcional à distância até a falta',
          'A diferença de frequência entre as extremidades da linha',
        ],
        correctIndex: 2,
        explanation: 'O relé calcula Z = V/I continuamente. Durante a falta, Z cai para Z_linha × (d/L), revelando a distância até o ponto de falta.',
      ),
      TrueFalse(
        id: 'mod03_l02_q2',
        statement: 'Uma vantagem do relé de distância sobre o sobrecorrente é que seu alcance é independente do nível de geração do sistema.',
        isTrue: true,
        explanation: 'Correto. Como a impedância de uma linha é característica física (resistência e reatância por km), o alcance do relé de distância não muda com variações de geração ou carga.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l03',
    title: 'Zona 1 — Atuação Instantânea',
    subtitle: 'Ajuste de 80-90% e prevenção de invasão de zona',
    content: r'''
## Zona 1: O Ajuste Instantâneo

A **Zona 1** oferece atuação **instantânea** (sem retardo de tempo) para faltas dentro de seu alcance.

### Por que 80-90% e não 100%?

O ajuste é tipicamente **80% a 90%** da impedância total da linha para evitar a **invasão de zona** (zone overreach).

**Zone overreach:** O relé atua para uma falta no barramento remoto (fora da linha), causando um desligamento indevido.

Causas de imprecisão que justificam a margem:
- Erros dos Transformadores de Corrente (TC) e de Tensão (TP)
- Variações de parâmetros da linha com temperatura
- Resistência de arco elétrico

### Cálculo do Alcance de Zona 1

$$Z_{Z1} = 0{,}85 \\times Z_{linha}$$

Por exemplo, linha com Z = 10 Ω:
- Zona 1 alcança: 0,85 × 10 = **8,5 Ω** (instantâneo)
- Os últimos 1,5 Ω (15% da linha) são cobertos pela Zona 2
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l03_q1',
        statement: 'Por que a Zona 1 da proteção de distância é ajustada para 80-90% e não 100% da impedância da linha?',
        options: [
          'Para economizar capacidade de processamento dos relés digitais',
          'Para prevenir invasão de zona (zone overreach) — atuação indevida para faltas no barramento remoto',
          'Porque os últimos 10-20% da linha têm impedância diferente',
          'Para compatibilidade com a regulamentação do operador da rede',
        ],
        correctIndex: 1,
        explanation: 'Erros de TC/TP e variações de parâmetros podem fazer o relé calcular uma impedância menor do que a real, podendo "enxergar" além da linha. A margem de 10-20% previne atuação indevida para faltas no barramento remoto.',
      ),
      TrueFalse(
        id: 'mod03_l03_q2',
        statement: 'A Zona 1 da proteção de distância opera com atraso de tempo para garantir coordenação com as proteções vizinhas.',
        isTrue: false,
        explanation: 'Falso. A Zona 1 é *instantânea* — sem atraso intencional. Ela cobre 80-90% da linha com operação na velocidade máxima do relé (~15-30 ms). O atraso de tempo é usado na Zona 2 e Zona 3.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l04',
    title: 'Zona 2 — Proteção com Retardo',
    subtitle: 'Alcance de 120% e coordenação com a extremidade remota',
    content: r'''
## Zona 2: Cobertura Total da Linha

A **Zona 2** cobre **120% da impedância da linha** e opera com um **retardo de tempo** (tipicamente 0,3 s).

### Objetivos da Zona 2

1. **Cobrir o segmento final da LT** (os ~15% não cobertos pela Zona 1)
2. **Proteger o barramento adjacente remoto** como proteção de retaguarda local

### Por que 120%?

O alcance de 120% garante cobertura da extremidade final da linha considerando os erros dos instrumentos de medição:

$$Z_{Z2} = 1{,}20 \\times Z_{linha}$$

### Coordenação do Tempo

O retardo de **~300 ms** garante coordenação com a proteção da LT adjacente:
- Se a falta está na Zona 1 do relé da extremidade remota → remoto atua instântaneamente (< 30 ms)
- Se remoto falha → Zona 2 local atua após 300 ms como backup

> ⚠️ A Zona 2 **não deve se sobrepor** à Zona 1 da linha adjacente mais curta, para evitar perda de seletividade.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l04_q1',
        statement: 'Por que a Zona 2 da proteção de distância opera com alcance de 120% da impedância da linha?',
        options: [
          'Para cobrir linhas de 120 km no sistema de transmissão',
          'Para garantir cobertura total da linha, compensando erros de medição e cobrindo o barramento remoto',
          'Para substituir completamente a Zona 3',
          'Porque 120% é o limite máximo permitido pela norma ANSI C37',
        ],
        correctIndex: 1,
        explanation: 'O alcance de 120% garante que toda a extensão da linha seja coberta, mesmo com erros de medição dos TCs e TPs. Também proporciona proteção de backup para o barramento remoto adjacente.',
      ),
      MultipleChoice(
        id: 'mod03_l04_q2',
        statement: 'O retardo de tempo de ~300 ms na Zona 2 serve para:',
        options: [
          'Permitir que a proteção da extremidade remota atue primeiro, se a falta for na sua área',
          'Aguardar a estabilização da corrente de falta antes de atuar',
          'Sincronizar com o oscilador da subestação',
          'Compensar o tempo de propagação do sinal de tensão',
        ],
        correctIndex: 0,
        explanation: 'O retardo garante coordenação: o relé remoto tem 300 ms para eliminar a falta em sua própria Zona 1 (~20-30 ms). Se ele falhar, a Zona 2 local atua como backup após 300 ms.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l05',
    title: 'Zona 3 — Proteção de Retaguarda Remota',
    subtitle: 'Cobertura de linhas adjacentes com maior retardo',
    content: r'''
## Zona 3: O Último Recurso

A **Zona 3** oferece proteção de **retaguarda remota** (*backup*) para os trechos de linhas adjacentes.

### Alcance e Tempo

- Alcance: tipicamente **cobre a linha protegida + a linha adjacente** mais longa
- Retardo: ainda maior que Zona 2 (ex: 0,6 a 1,0 s)

### Hierarquia Completa de Atuação

```
Falta na linha → 
  Z₁ local atua instantaneamente (< 30 ms) ✅

Se Z₁ local falhar →
  Z₂ local atua com 300 ms ✅

Se Z₂ local falhar →
  Z₃ do relé a montante atua com 600-1000 ms ✅
```

### Problema: Alcance de Retaguarda vs. Cargas Pesadas

A Zona 3 com grande alcance pode **interpretar cargas pesadas** (alta carga, baixa tensão) como falta. Esse é o risco de **overreach de carga**, que deve ser verificado no projeto.
    ''',
    questions: [
      TrueFalse(
        id: 'mod03_l05_q1',
        statement: 'A Zona 3 da proteção de distância oferece retaguarda para linhas adjacentes e tem o maior atraso de tempo entre as três zonas principais.',
        isTrue: true,
        explanation: 'Correto. A Zona 3 é o último nível de backup, com maior alcance e maior atraso (tipicamente 0,6 a 1,0 s) para garantir que as zonas 1 e 2 atuem primeiro.',
      ),
      MultipleChoice(
        id: 'mod03_l05_q2',
        statement: 'O fenômeno de "overreach de carga" na Zona 3 ocorre quando:',
        options: [
          'A corrente de carga supera a corrente nominal do relé',
          'O relé interpreta uma condição de carga pesada (alta corrente, baixa tensão) como uma falta na sua zona de alcance',
          'A linha adjacente entra em sobrecarrega elétrica',
          'Dois relés atuam simultaneamente para a mesma falta',
        ],
        correctIndex: 1,
        explanation: 'Com carga pesada, a tensão pode cair e a corrente subir, fazendo Z = V/I diminuir — o relé pode "enxergar" essa impedância como estando dentro da Zona 3, atuando erroneamente.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l06',
    title: 'O Plano de Impedâncias — R-X',
    subtitle: 'Visualização do alcance das zonas no plano complexo',
    content: r'''
## O Plano de Impedâncias (R × X)

A representação das zonas de proteção é feita no **plano complexo de impedâncias** (R no eixo horizontal, X no eixo vertical).

### Por que o Plano de Impedâncias?

Cada ponto no plano representa uma impedância Z = R + jX vista pelo relé:

```
    jX (reatância)
     ↑
     │          ╱ impedância da linha
     │         ╱  (ângulo ≈ 75-85°)
     │    Z₁  ╱  Z₂   Z₃
     │   ●───●────●
     │  /
     │ / ← alcance das zonas ao longo da linha
     └──────────────────→ R (resistência)
```

### Representação das Zonas

No plano R-X:
- A **impedância da linha** é representada por uma reta com ângulo típico de 75° a 85°
- As zonas são regiões geométricas ao redor da origem
- Qualquer impedância calculada **dentro da zona** → relé atua
- Impedâncias **fora** → relé bloqueia
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l06_q1',
        statement: 'No plano de impedâncias (R × X) de um relé de distância, o relé atua quando a impedância calculada Z = V/I:',
        options: [
          'Está acima do ângulo de 75°',
          'Está dentro da região geométrica de atuação (zona definida)',
          'É maior que a impedância da linha total',
          'Está no eixo real (componente resistiva dominante)',
        ],
        correctIndex: 1,
        explanation: 'O relé de distância atua quando a impedância calculada cai dentro da região geométrica de sua zona no plano R-X. Durante uma falta, Z cai de valores altos (carga) para valores baixos (falta).',
      ),
      TrueFalse(
        id: 'mod03_l06_q2',
        statement: 'A impedância de uma linha de transmissão é representada no plano R-X como uma reta com ângulo típico de 75° a 85° em relação ao eixo resistivo.',
        isTrue: true,
        explanation: 'Correto. Linhas de transmissão têm alta relação X/R (tipicamente X >> R), resultando em ângulo de 75° a 85° no plano R-X. Linhas de distribuição têm ângulos menores.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l07',
    title: 'Característica Tipo Mho',
    subtitle: 'Formato circular, direcionalidade natural e aplicação em sistemas de transmissão',
    content: r'''
## A Característica Mho (Circular)

A característica **Mho** (ou admitância — o inverso de Ω) tem formato **circular** no plano de impedâncias.

### Propriedades Fundamentais

1. **Forma circular:** A região de atuação é um círculo que passa pela origem
2. **Naturalmente direcional:** A geometria circular garante que o relé não atua para faltas na direção oposta (atrás do relé)
3. **Não requer elemento direcional separado:** A direcionalidade é intrínseca ao formato

### Quando Usar a Característica Mho?

```
    jX
     │      ╭──────╮
     │    ╭─╯  ✅   ╰─╮
     │   ╭╯  atua aqui ╰╮
     │──●────────────────→ R
     │Origem  (falta à frente)
     │
     │  ❌ (atrás do relé — não atua)
```

**Melhor aplicação:** Longas linhas de transmissão por:
- Simplicidade de ajuste (parâmetro único: diâmetro do círculo)
- Alta imunidade à carga (geometria circular naturalmente separa carga de falta)
- Robustez comprovada em décadas de uso
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l07_q1',
        statement: 'A principal vantagem da característica Mho em relação a outras características de relés de distância é:',
        options: [
          'Sua capacidade de cobrir faltas com alta resistência de falta',
          'Sua direcionalidade intrínseca ao formato circular, sem necessidade de elemento direcional separado',
          'Seu alcance variável conforme a corrente de falta',
          'Sua imunidade total a erros de medição dos transformadores de corrente',
        ],
        correctIndex: 1,
        explanation: 'O formato circular da Mho faz com que apenas impedâncias à frente do relé caiam dentro da zona de atuação, tornando-a naturalmente direcional sem necessidade de elemento adicional.',
      ),
      TrueFalse(
        id: 'mod03_l07_q2',
        statement: 'A característica Mho é especialmente adequada para proteção de longas linhas de transmissão devido à sua direcionalidade intrínseca e alta imunidade à condição de carga pesada.',
        isTrue: true,
        explanation: 'Correto. Linhas longas de transmissão se beneficiam da Mho pois: (1) é direcional sem elemento adicional, (2) faltas típicas (baixa resistência) ficam claramente dentro da zona circular, longe da região de carga.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l08',
    title: 'Característica Tipo Quadrilateral',
    subtitle: 'Ajuste independente e cobertura de faltas resistivas',
    content: r'''
## A Característica Quadrilateral

A característica **Quadrilateral** define uma região de atuação em formato retangular/poligonal no plano R-X.

### Diferença Fundamental: Ajuste Independente

| Parâmetro | Mho (Circular) | Quadrilateral |
|-----------|----------------|---------------|
| **Alcance reativo (X)** | Acoplado ao raio | Ajustável independentemente |
| **Alcance resistivo (R)** | Limitado pelo raio | Ajustável independentemente |

### Por que Independência é Vantajosa?

```
    jX
     │    ┌────────────────┐
     │    │   ✅ atua aqui  │
     │    │                │ ← alcance resistivo
     │    │    Quadrilateral│   ajustável
     │────┼────────────────┤──→ R
     │    │ alcance        │
     │    └────────────────┘
     │      reativo ajustável
```

### Melhor Aplicação: Faltas com Alta Resistência

Faltas como **contato de galho de árvore** têm alta resistência de arco (dezenas a centenas de Ω). No plano R-X, a impedância dessas faltas fica deslocada para direita (alto R).

A **Mho** pode **não alcançar** essas faltas resistivas. O **Quadrilateral**, com ajuste independente do alcance resistivo, cobre essas situações.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l08_q1',
        statement: 'A característica Quadrilateral é preferida à Mho quando existem faltas com:',
        options: [
          'Baixa impedância de sequência zero',
          'Alta resistência de arco (ex: galho de árvore, solo úmido)',
          'Curta distância da subestação',
          'Sistema fortemente malhadado',
        ],
        correctIndex: 1,
        explanation: 'Faltas resistivas (galhos, solo, arco) têm grande componente R no plano de impedâncias. O ajuste independente do alcance resistivo do quadrilateral permite cobrir essas faltas que a Mho poderia perder.',
      ),
      MultipleChoice(
        id: 'mod03_l08_q2',
        statement: 'A principal vantagem do Quadrilateral sobre a Mho é:',
        options: [
          'Maior velocidade de atuação',
          'Ajuste independente do alcance resistivo e reativo',
          'Maior imunidade a erros de TC',
          'Menor custo de implementação',
        ],
        correctIndex: 1,
        explanation: 'No Quadrilateral, o alcance reativo (X) e o alcance resistivo (R) são ajustados de forma independente, permitindo otimização específica para cada tipo de falta.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l09',
    title: 'Impedância de Carga vs. Impedância de Falta',
    subtitle: 'Discriminação entre condições de operação normal e falta',
    content: r'''
## O Relé Deve Distinguir Carga de Falta

### Impedância em Condição de Carga Normal

$$Z_{carga} = \\frac{V_{nominal}}{I_{carga}} \\gg Z_{linha}$$

Com plena tensão e corrente de carga típica, Z_carga é grande — **longe da origem** no plano R-X.

### Impedância Durante Falta

$$Z_{falta} = Z_{linha} \\times \\frac{d_{falta}}{L} \\ll Z_{carga}$$

Z_falta é pequena, proporcional à distância — **próxima da origem** no plano R-X.

### O Problema com Carga Pesada

Em condições de **carga máxima + tensão baixa**, Z_carga pode se aproximar de Z_zona3, causando risco de:

**Load encroachment:** O relé de distância atuaria indevidamente durante carga pesada.

### Soluções
1. **Função de load encroachment:** Bloco a atuação em região de carga (ângulo de potência ativo)
2. **Monitoramento de V e I** para verificar condição real
3. **Redução do alcance da Zona 3** para menor risco
    ''',
    questions: [
      TrueFalse(
        id: 'mod03_l09_q1',
        statement: 'Durante uma condição de falta, a impedância calculada pelo relé de distância cai para um valor próximo da origem no plano R-X.',
        isTrue: true,
        explanation: 'Correto. Durante falta, a tensão cai e a corrente sobe, fazendo Z = V/I se tornar pequeno — proporcional à distância da falta. Em carga normal, Z é muito maior.',
      ),
      MultipleChoice(
        id: 'mod03_l09_q2',
        statement: 'O fenômeno de "load encroachment" em relés de distância ocorre quando:',
        options: [
          'Duas faltas ocorrem simultaneamente na mesma linha',
          'A impedância de carga pesada penetra na região de atuação da zona do relé',
          'O TC entra em saturação durante alta corrente de carga',
          'A linha atinge 100% de sua capacidade térmica',
        ],
        correctIndex: 1,
        explanation: 'Load encroachment ocorre quando Z_carga cai dentro da zona do relé (condição de máxima carga + mínima tensão), podendo causar atuação indevida. É mitigado pela função de bloqueio de carga.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l10',
    title: 'Efeito de Infeed na Proteção de Distância',
    subtitle: 'Como correntes intermediárias afetam o alcance aparente',
    content: r'''
## O Problema do Infeed

O **infeed** ocorre quando existe **outra fonte de corrente** conectada a um barramento intermediário entre o relé e o ponto de falta.

### Como o Infeed Distorce a Medição?

```
   [Relé A] ──── [Barra B] ──── [Falta]
                    │
                [Gerador B]  ← contribuição de infeed
```

O relé A mede I_A, mas na região da falta a corrente é I_A + I_B.

**Impedância aparente vista pelo relé A:**

$$Z_{aparente} = \\frac{V_A}{I_A} = Z_{AB} + \\frac{I_A + I_B}{I_A} \\times Z_{BF}$$

O relé "enxerga" uma impedância **maior** que a real — o alcance aparente é menor.

### Consequência Prática

A Zona 2 do relé A pode **não alcançar** o ponto de falta na linha adjacente quando há infeed significativo no barramento intermediário.

### Solução

Considerar o fator de infeed **no ajuste das zonas**, especialmente Zone 2 e Zone 3.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l10_q1',
        statement: 'O efeito de infeed em proteção de distância faz com que o relé "pareça" que a falta está:',
        options: [
          'Mais próxima do que realmente está (alcance aumentado)',
          'Na mesma posição calculada (sem efeito)',
          'Mais distante do que realmente está (alcance reduzido aparente)',
          'Na barra de infeed, independente da posição real',
        ],
        correctIndex: 2,
        explanation: 'O infeed adiciona corrente no ponto de falta sem passar pelo relé, elevando a impedância aparente calculada. O relé "enxerga" uma falta mais distante do que está realmente.',
      ),
      TrueFalse(
        id: 'mod03_l10_q2',
        statement: 'O efeito de infeed deve ser considerado especialmente no ajuste das Zonas 2 e 3, que se destinam a cobrir linhas adjacentes.',
        isTrue: true,
        explanation: 'Correto. O infeed afeta principalmente as zonas que "alcançam" além da linha protegida. A Zona 1 raramente é afetada pois está dentro da própria linha.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_l11',
    title: 'Sinalização Piloto — PUTT e POTT',
    subtitle: 'Eliminação de falta em 100% da linha com comunicação',
    content: '## Em desenvolvimento\n\nConteúdo: PUTT (Permissive Underreaching Transfer Trip) e POTT (Permissive Overreaching), vantagens e circuitos de comunicação.',
    questions: [],
  ),
  Lesson(
    id: 'mod03_l12',
    title: 'Proteção de Linha em Sistemas de Distribuição',
    subtitle: 'Aplicações da proteção de distância em redes de distribuição',
    content: '## Em desenvolvimento\n\nConteúdo: Características específicas, linhas curtas, resistência de falta e seletividade.',
    questions: [],
  ),
  Lesson(
    id: 'mod03_l13',
    title: 'Relés de Distância Digitais — Configuração e IED',
    subtitle: 'Parametrização de relés modernos para proteção de LT',
    content: '## Em desenvolvimento\n\nConteúdo: Ajuste de alcances, grupos de ajuste, comunicação IEC 61850.',
    questions: [],
  ),
  Lesson(
    id: 'mod03_l14',
    title: 'Distúrbios de Swing — Oscilações de Potência',
    subtitle: 'Diferenciação entre swing elétrico e falta',
    content: '## Em desenvolvimento\n\nConteúdo: Power swing blocking, out-of-step tripping, critério de slip frequency.',
    questions: [],
  ),
  Lesson(
    id: 'mod03_l15',
    title: 'Estudos de Caso — Proteção de Interligações',
    subtitle: 'Aplicação prática em sistemas de transmissão brasileiros',
    content: '## Em desenvolvimento\n\nConteúdo: Casos reais de coordenação em sistemas interligados, eventos históricos.',
    questions: [],
  ),
  Lesson(
    id: 'mod03_l16',
    title: 'Revisão Geral — Módulo 03',
    subtitle: 'Consolidação: Distância, Zonas, Mho e Quadrilateral',
    content: r'''
## Revisão: Módulo 03 — Pontos Essenciais

### Proteção de Distância (ANSI 21)
- Mede Z = V/I — proporcional à distância até a falta
- Independente do nível de geração — robusto em sistemas com DER

### Zonas de Alcance
| Zona | Alcance | Atuação |
|------|---------|---------|
| **Zona 1** | 80-90% da linha | Instantânea |
| **Zona 2** | 120% da linha | ~300 ms (backup do barramento remoto) |
| **Zona 3** | Linha + adjacente | 600-1000 ms (retaguarda remota) |

### Características no Plano R-X
- **Mho (circular):** Naturalmente direcional; ideal para longas LTs de transmissão
- **Quadrilateral:** Alcance R e X independentes; ideal para faltas resistivas (galhos)

### Atenção nos Projetos
- Mare de 80-90% na Z1 previne zone overreach
- Infeed reduz alcance aparente → compensar no ajuste
- Load encroachment → função de bloqueio de carga
    ''',
    questions: [
      MultipleChoice(
        id: 'mod03_l16_q1',
        statement: 'Qual característica de relé de distância é mais adequada para cobrir faltas causadas por contato com vegetação (galho de árvore), que têm alta resistência de arco?',
        options: ['Mho (circular)', 'Quadrilateral', 'Direcional de sobrecorrente', 'Relé de impedância puro'],
        correctIndex: 1,
        explanation: 'Faltas com vegetação têm alta resistência → deslocamento para direita no plano R-X. O Quadrilateral, com alcance resistivo ajustável independentemente, cobre essas faltas que a Mho poderia não alcançar.',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════
  //  AVALIAÇÕES (3)
  // ══════════════════════════════════════════════════════════════

  Lesson(
    id: 'mod03_eval1',
    title: 'Avaliação 1 · Princípios da Proteção de Distância',
    subtitle: 'Função ANSI 21, medição de impedância e zonas',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod03_eval1_q1',
        statement: 'Por que a proteção de distância (ANSI 21) é superior ao relé de sobrecorrente (51) em longas linhas de transmissão?',
        options: [
          'Por ser mais barata e simples de instalar',
          'Porque seu alcance é baseado em impedância, não em corrente, sendo independente do nível de geração',
          'Porque opera apenas com tensão, sem necessidade de TC',
          'Porque cobre 100% da linha com atuação instantânea',
        ],
        correctIndex: 1,
        explanation: 'A proteção de distância mede Z = V/I, que é proporcional à distância e independente do nível de geração. Relés 51 têm dificuldade de discriminar faltas distantes de carga pesada em sistemas de transmissão.',
      ),
      TrueFalse(
        id: 'mod03_eval1_q2',
        statement: 'A Zona 1 é ajustada para 80-90% da impedância da linha para evitar atuação indevida para faltas no barramento remoto (zone overreach).',
        isTrue: true,
        explanation: 'Correto. Os erros de medição dos TCs e TPs podem fazer o relé calcular Z menor que o real. A margem de 10-20% previne atuação da Z1 para faltas no barramento remoto.',
      ),
      MultipleChoice(
        id: 'mod03_eval1_q3',
        statement: 'A Zona 2 da proteção de distância tem retardo de ~300 ms para:',
        options: [
          'Aguardar a estabilização da corrente de curto-circuito',
          'Permitir que a proteção da extremidade remota atue primeiro (se falta for Zona 1 do remoto)',
          'Sincronizar com o ciclo da rede de 60 Hz',
          'Compensar o tempo de abertura do TC',
        ],
        correctIndex: 1,
        explanation: 'O retardo de Z2 permite que o relé da extremidade remota atue em sua Zona 1 (~20-30 ms). Se o remoto falhar, Z2 atua como backup após ~300 ms.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_eval2',
    title: 'Avaliação 2 · Características Mho e Quadrilateral',
    subtitle: 'Diferenças e aplicações das características no plano R-X',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod03_eval2_q1',
        statement: 'A característica Mho é "naturalmente direcional" porque:',
        options: [
          'Possui um elemento direcional integrado no hardware',
          'O formato circular faz com que apenas impedâncias à frente do relé caiam dentro da zona',
          'Mede o ângulo de potência para determinar a direção',
          'É ajustada manualmente para uma direção específica',
        ],
        correctIndex: 1,
        explanation: 'O círculo da Mho passa pela origem de tal forma que geometricamente apenas impedâncias "à frente" (na linha protegida) ficam dentro da zona. Faltas "atrás" do relé produzem impedâncias fora do círculo.',
      ),
      MultipleChoice(
        id: 'mod03_eval2_q2',
        statement: 'A característica Quadrilateral oferece cobertura superior para faltas resistivas porque:',
        options: [
          'Tem maior velocidade de atuação que a Mho',
          'Seu alcance resistivo (eixo R) é ajustável independentemente do alcance reativo (eixo X)',
          'Usa curvas de tempo inverso para faltas de alta resistência',
          'Não requer transformadores de tensão (TP) para operar',
        ],
        correctIndex: 1,
        explanation: 'Faltas resistivas se deslocam para a direita no plano R-X. O ajuste independente do alcance resistivo do Quadrilateral permite cobrir essa região sem comprometer a imunidade à carga.',
      ),
      TrueFalse(
        id: 'mod03_eval2_q3',
        statement: 'O efeito de infeed faz o relé de distância calcular uma impedância MENOR que a real, aumentando seu alcance aparente.',
        isTrue: false,
        explanation: 'Falso. O infeed faz o relé calcular uma impedância MAIOR que a real (alcance aparente MENOR). A corrente extra na falta (do infeed) não passa pelo relé, elevando Z = V/I.',
      ),
    ],
  ),

  Lesson(
    id: 'mod03_eval3',
    title: 'Avaliação Final · Módulo 03',
    subtitle: 'Avaliação integrada — Proteção de Linhas de Transmissão',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod03_eval3_q1',
        statement: 'Qual das afirmações abaixo sobre as zonas de distância está CORRETA?',
        options: [
          'Zona 1 cobre 120% com retardo; Zona 2 cobre 80-90% instantânea',
          'Zona 1: 80-90% instantânea; Zona 2: 120% com ~300 ms; Zona 3: backup remoto com maior retardo',
          'Zona 2 e Zona 3 possuem o mesmo tempo de retardo',
          'A Zona 3 cobre apenas a linha protegida sem alcançar as adjacentes',
        ],
        correctIndex: 1,
        explanation: 'Hierarquia correta: Z1 (80-90%, instantânea), Z2 (120%, ~300 ms), Z3 (backup remoto, 600-1000 ms). Cada zona tem alcance e tempo crescentes.',
      ),
      TrueFalse(
        id: 'mod03_eval3_q2',
        statement: 'A característica Mho é mais indicada para proteção de longas linhas de transmissão, enquanto o Quadrilateral é preferido para linhas de distribuição com alta resistência de falta.',
        isTrue: true,
        explanation: 'Correto. Mho: simples, direcional, ideal para LTs onde as faltas são predominantemente de baixa resistência. Quadrilateral: essencial para distribuição onde a resistência de falta pode ser muito alta.',
      ),
      MultipleChoice(
        id: 'mod03_eval3_q3',
        statement: 'O fenômeno de "load encroachment" afeta principalmente qual zona da proteção de distância?',
        options: ['Zona 1', 'Zona 2', 'Zona 3', 'Afeta igualmente todas as zonas'],
        correctIndex: 2,
        explanation: 'A Zona 3, por ter maior alcance, é a mais vulnerável ao load encroachment, pois sua região de atuação pode se aproximar da região de carga no plano R-X durante condições de máxima carga.',
      ),
      FillInTheBlanks(
        id: 'mod03_eval3_q4',
        statement: 'Preencha sobre as características de relé de distância:',
        textWithBlanks: 'A característica ____ tem formato circular e é naturalmente direcional. A característica ____ tem ajuste independente de alcance resistivo e reativo.',
        blanks: [
          Blank(index: 0, answer: 'Mho'),
          Blank(index: 1, answer: 'Quadrilateral'),
        ],
        explanation: 'Mho: circular, direcional intrínseca, ideal para LTs. Quadrilateral: R e X ajustáveis independentemente, superior para faltas resistivas.',
      ),
    ],
  ),
];
