import 'package:spark_app/models/quiz_models.dart';

// ─────────────────────────────────────────────────────────────────
//  BLOCO 1 — MÓDULO 02: Filosofia de Proteção – Zonas e Seletividade
//  12 Lições + 2 Avaliações
// ─────────────────────────────────────────────────────────────────

final List<Lesson> mod02Lessons = [

  Lesson(
    id: 'mod02_l01',
    title: 'Objetivos Fundamentais da Proteção Elétrica',
    subtitle: 'Segurança, continuidade e integridade do sistema',
    content: r'''
## O que um Sistema de Proteção Deve Fazer?

O objetivo fundamental é **isolar apenas a porção do sistema onde ocorre a falha**, mantendo o restante da rede em operação.

### Três Parâmetros Essenciais em Equilíbrio

| Parâmetro | Definição | Trade-off |
|-----------|-----------|-----------|
| **Sensibilidade** | Capacidade de detectar mínimas faltas | ↑ Sensibilidade → ↑ risco de atuação indevida |
| **Velocidade** | Rapidez de atuação após a falta | ↑ Velocidade → ↓ seletividade |
| **Seletividade** | Isolar apenas o elemento com defeito | ↑ Seletividade → ↑ tempo de atuação |

> ⚡ O desafio do engenheiro de proteção é **equilibrar** esses três parâmetros para cada aplicação específica.

### Consequências de Falha na Proteção
- **Suboperação:** Relé não atua → equipamentos danificados, incêndio, colapso do sistema
- **Sobreopereação:** Relé atua indevidamente → desligamentos desnecessários, prejuízo ao fornecimento
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l01_q1',
        statement: 'Qual é o objetivo fundamental de um esquema de proteção elétrica?',
        options: [
          'Desligar todo o sistema ao menor sinal de anomalia',
          'Isolar apenas a porção do sistema onde ocorre a falha, mantendo o restante em operação',
          'Proteger exclusivamente os transformadores e geradores',
          'Monitorar a qualidade de energia sem intervir no sistema',
        ],
        correctIndex: 1,
        explanation: 'A proteção deve ser seletiva: atuar apenas no elemento com defeito, isolando-o rapidamente enquanto mantém o restante da rede em operação normal.',
      ),
      MultipleChoice(
        id: 'mod02_l01_q2',
        statement: 'Quando um relé atua em condição normal (sem falta), caracterizando um desligamento desnecessário, diz-se que houve:',
        options: ['Suboperação', 'Sobreopereação', 'Sensibilidade excessiva', 'Falha de coordenação'],
        correctIndex: 1,
        explanation: 'Sobreopereação (ou atuação indevida) ocorre quando o relé desliga o equipamento sem necessidade, causando prejuízo ao fornecimento sem existir uma falta real.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l02',
    title: 'Zonas de Proteção — Conceito e Delimitação',
    subtitle: 'Como dividir o sistema em zonas de proteção',
    content: r'''
## O Sistema Dividido em Zonas

O sistema de potência é dividido em **zonas de proteção**, geralmente delimitadas em torno de componentes principais:

- Barramentos (bus)
- Transformadores
- Linhas de transmissão
- Geradores
- Motores e cargas

### Princípio Básico
Cada zona possui um **relé primário** responsável por sua proteção e **equipamentos de corte** (disjuntores) em seus limites.

### Componentes de Uma Zona
```
       Z O N A   1          |      Z O N A   2
  ─────────────────────     |  ─────────────────
  [Gerador] ──[DJ1]──[TF]──[DJ2]──[Linha]──[DJ3]
                ↑                           ↑
           Relé Z1                     Relé Z2
```

Cada disjuntor pertence **simultaneamente a duas zonas** (a que ele delimita).
    ''',
    questions: [
      TrueFalse(
        id: 'mod02_l02_q1',
        statement: 'As zonas de proteção em um sistema elétrico são tipicamente delimitadas em torno de componentes como transformadores, barramentos e linhas de transmissão.',
        isTrue: true,
        explanation: 'Correto. Cada zona é definida ao redor de um elemento principal do sistema, com os disjuntores nos limites fazendo a separação física entre zonas adjacentes.',
      ),
      MultipleChoice(
        id: 'mod02_l02_q2',
        statement: 'Os disjuntores que delimitam duas zonas de proteção adjacentes pertencem:',
        options: [
          'Apenas à zona à montante',
          'Apenas à zona à jusante',
          'A ambas as zonas simultaneamente',
          'A uma zona neutra independente',
        ],
        correctIndex: 2,
        explanation: 'Cada disjuntor de fronteira pertence simultaneamente às duas zonas que ele separa. Isso é essencial para garantir o overlap e a proteção total.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l03',
    title: 'Sobreposição de Zonas (Overlap)',
    subtitle: 'Por que as zonas devem se sobrepor nos disjuntores',
    content: r'''
## O Overlap é Obrigatório

As zonas de proteção **devem se sobrepor nos disjuntores** para garantir que absolutamente **nenhuma parte do sistema fique sem proteção** — o conceito de cobertura total.

### Por que o Overlap Existe?

Se as zonas fossem contíguas sem sobreposição, os disjuntores de fronteira ficariam em uma "zona morta" — não pertencendo a nenhuma zona de proteção.

### Funcionamento na Região de Overlap

Se uma falta ocorrer **na região de sobreposição** (dentro do disjuntor):

> Todos os disjuntores de **ambas as zonas** irão desarmar.

Este é um **compromisso necessário**: aceita-se um desligamento maior em troca da garantia de cobertura total.

### Consequência Prática
- Faltas no overlap causam isolamento de duas zonas
- É uma situação rara, mas prevista no projeto
- Aceitável pois garante que NENHUMA falta ficará sem proteção
    ''',
    questions: [
      TrueFalse(
        id: 'mod02_l03_q1',
        statement: 'Se uma falta ocorrer na região de sobreposição (overlap) entre duas zonas de proteção, todos os disjuntores de AMBAS as zonas devem desarmar.',
        isTrue: true,
        explanation: 'Correto. Faltas no overlap ativam as proteções de ambas as zonas, causando um desligamento maior. Isso é aceito como compromisso para garantir proteção total — sem zonas mortas.',
      ),
      MultipleChoice(
        id: 'mod02_l03_q2',
        statement: 'O principal motivo para as zonas de proteção se sobreporem nos disjuntores é:',
        options: [
          'Aumentar a velocidade de atuação dos relés',
          'Garantir que nenhuma parte do sistema fique sem proteção (sem zonas mortas)',
          'Reduzir o custo dos sistemas de proteção',
          'Facilitar o ajuste de temporização dos relés',
        ],
        correctIndex: 1,
        explanation: 'O overlap garante cobertura total do sistema, evitando "zonas mortas" onde uma falta poderia não ser detectada por nenhum relé de proteção.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l04',
    title: 'Seletividade — Conceito e Classificação',
    subtitle: 'Os três tipos de seletividade em sistemas de proteção',
    content: r'''
## O que é Seletividade?

A **seletividade** é o critério que garante que o **disjuntor mais próximo à falha atue primeiro**, preservando o máximo possível do sistema em operação.

### Classificação dos Tipos de Seletividade

```
           SELETIVIDADE
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
Amperimétrica Cronométrica  Lógica
(Corrente)    (Tempo)    (Comunicação)
```

| Tipo | Princípio | Melhor Aplicação |
|------|-----------|-----------------|
| **Amperimétrica** | Diferença de nível de corrente | Alta impedância entre estágios (transformadores) |
| **Cronométrica** | Atrasos de tempo escalonados | Sistemas radiais de distribuição |
| **Lógica** | Comunicação entre relés | Sistemas complexos, alta sensibilidade |

> 💡 Na prática, os sistemas de proteção combinam dois ou mais tipos de seletividade para maximizar a confiabilidade.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l04_q1',
        statement: 'A seletividade é definida como o critério que garante:',
        options: [
          'Que todos os disjuntores atuem simultaneamente em qualquer falta',
          'Que o disjuntor mais próximo à falha atue primeiro',
          'Que apenas o relé de maior corrente nominal atue',
          'Que a falta seja eliminada no menor tempo possível, independente da zona',
        ],
        correctIndex: 1,
        explanation: 'Seletividade significa que o elemento de proteção mais próximo ao defeito deve atuar primeiro, isolando apenas o elemento com falha e preservando o restante do sistema.',
      ),
      TrueFalse(
        id: 'mod02_l04_q2',
        statement: 'Na prática, os sistemas de proteção modernos combinam dois ou mais tipos de seletividade para maximizar a confiabilidade.',
        isTrue: true,
        explanation: 'Correto. Sistemas reais frequentemente usam seletividade cronométrica como proteção primária e lógica ou amperimétrica como backup, combinando as vantagens de cada abordagem.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l05',
    title: 'Seletividade Amperimétrica',
    subtitle: 'Coordenação por diferença de níveis de corrente de curto',
    content: r'''
## Seletividade Amperimétrica

A **seletividade amperimétrica** utiliza a diferença nos **níveis de corrente de curto-circuito** entre a fonte e a carga para discriminar qual relé deve atuar.

### Como Funciona?

Em um sistema radial, a corrente de curto-circuito é maior próximo à fonte e menor à medida que se afasta:

```
   Fonte → [R₁ pickup: 1000A] → TF → [R₂ pickup: 200A] → Carga
   I_cc = 3000A                        I_cc = 500A
```

- Falta no lado da carga: R₂ atua (corrente = 500A > 200A; R₁: 500A < 1000A, não atua)
- Falta antes do TF: R₁ atua (corrente = 3000A > 1000A)

### Condição de Aplicabilidade

Requer **alta impedância** separando os estágios — geralmente fornecida por um **transformador**.

> ⚠️ Sem uma queda de corrente significativa entre estágios, os relés não conseguem discriminar a localização da falta apenas pela corrente.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l05_q1',
        statement: 'A seletividade amperimétrica é mais aplicada quando existe:',
        options: [
          'Baixa impedância entre os estágios de proteção',
          'Alta impedância entre os estágios de proteção, como em transformadores',
          'Sistemas em anel sem transformadores',
          'Distâncias muito pequenas entre as subestações',
        ],
        correctIndex: 1,
        explanation: 'A seletividade amperimétrica depende de uma queda significativa na corrente de curto entre estágios — condição geralmente atendida por transformadores, que introduzem alta impedância.',
      ),
      TrueFalse(
        id: 'mod02_l05_q2',
        statement: 'Na seletividade amperimétrica, o relé mais próximo da fonte tem pickup (ajuste de atuação) MAIOR que o relé mais próximo da carga.',
        isTrue: true,
        explanation: 'Correto. O relé próximo à fonte vê correntes maiores (nível superior de curto). Seu pickup é ajustado acima do nível de curto do estágio seguinte, garantindo discriminação por nível de corrente.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l06',
    title: 'Seletividade Cronométrica (por Tempo)',
    subtitle: 'Atrasos escalonados e intervalo de coordenação',
    content: r'''
## Seletividade Cronométrica

A **seletividade cronométrica** baseia-se no ajuste de **diferentes atrasos de tempo** para os relés localizados a montante do defeito.

### Princípio de Escalonamento

```
   Falta → [R_jusante: t=0s] → [R_intermediário: t=0,3s] → [R_montante: t=0,6s]
                 ↑ atua primeiro se a falta for na sua zona
```

O relé mais próximo da falta tem o **menor tempo de atuação**. O de retaguarda espera para ver se o anterior atuou.

### Intervalo de Coordenação de Tempo (CTI)

O intervalo entre estágios tipicamente varia de **0,2 a 0,4 segundos** para compensar:

| Componente | Tempo Típico |
|------------|-------------|
| Tempo de abertura do disjuntor | 0,05 – 0,10 s |
| Overshoot mecânico/elétrico do relé | 0,05 – 0,10 s |
| Margem de segurança | 0,10 – 0,20 s |
| **Total (CTI)** | **0,20 – 0,40 s** |

> ⚠️ Usar CTI menor que 0,2 s aumenta o risco de perda de coordenação (ambos atuam juntos).
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l06_q1',
        statement: 'O Intervalo de Coordenação de Tempo (CTI) entre estágios de proteção cronométrica normalmente varia de:',
        options: ['0,05 a 0,10 segundos', '0,10 a 0,20 segundos', '0,2 a 0,4 segundos', '0,5 a 1,0 segundo'],
        correctIndex: 2,
        explanation: 'O CTI de 0,2 a 0,4 s é necessário para acomodar o tempo de abertura do disjuntor, o overshoot do relé e uma margem de segurança, garantindo coordenação adequada.',
      ),
      FillInTheBlanks(
        id: 'mod02_l06_q2',
        statement: 'Complete sobre o intervalo de coordenação de tempo (CTI):',
        textWithBlanks: 'O CTI compensa o tempo de ____ do disjuntor, o ____ mecânico do relé e a margem de segurança.',
        blanks: [
          Blank(index: 0, answer: 'abertura'),
          Blank(index: 1, answer: 'overshoot'),
        ],
        explanation: 'O CTI deve ser suficiente para: (1) o disjuntor abrir, (2) o relé superar seu overshoot e (3) garantir margem de segurança, totalizando 0,2 a 0,4 segundos.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l07',
    title: 'Seletividade Lógica',
    subtitle: 'Comunicação entre relés para atuação inteligente',
    content: r'''
## Seletividade Lógica

A **seletividade lógica** funciona por meio de **comunicação direta entre os relés**, eliminando a dependência de atrasos de tempo.

### Funcionamento

1. Um relé a **jusante** detecta a falta
2. Ele emite um **sinal de bloqueio** para o relé a montante
3. O relé a montante:
   - **Recebe o sinal:** aguarda — a falta está na zona do relé vizinho
   - **Não recebe o sinal** (mas vê corrente de falta): atua **instantaneamente** — a falta está na sua zona primária

### Exemplo Prático

```
   [R_montante] ←── sinal de bloqueio ── [R_jusante]
        │                                     │
   sem sinal → atua            detecta falta → bloqueia montante
   inst. (zona A)               e atua (zona B)
```

### Vantagens sobre a Cronométrica
- **Velocidade:** Atuação instantânea em qualquer ponto, sem esperar pelo tempo de coordenação
- **Sensibilidade:** Pode usar pickups menores, pois não há risco de sobreopereação por tempo
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l07_q1',
        statement: 'Na seletividade lógica, se o relé a montante detecta corrente de falta mas NÃO recebe sinal de bloqueio, ele deve:',
        options: [
          'Aguardar o tempo de coordenação antes de atuar',
          'Atuar imediatamente — a falta está na sua zona primária local',
          'Bloquear o relé vizinho',
          'Enviar alarme sem atuar',
        ],
        correctIndex: 1,
        explanation: 'Sem sinal de bloqueio do relé a jusante (que já teria atuado se a falta fosse na zona dele), o relé a montante infere que a falta está na sua própria zona e atua instantaneamente.',
      ),
      TrueFalse(
        id: 'mod02_l07_q2',
        statement: 'Uma vantagem da seletividade lógica sobre a cronométrica é que ela permite atuação instantânea em qualquer zona, sem necessidade de escalonamento de tempos.',
        isTrue: true,
        explanation: 'Correto. A seletividade lógica elimina os atrasos de tempo ao usar comunicação entre relés, permitindo atuação rápida em toda a extensão do sistema.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l08',
    title: 'Proteção Principal e de Retaguarda (Backup)',
    subtitle: 'Redundância e hierarquia de proteções',
    content: r'''
## Proteção Principal vs. Retaguarda

Todo sistema de proteção deve ter **redundância** — uma proteção de retaguarda que atua se a principal falhar.

### Hierarquia

| Nível | Nome | Função |
|-------|------|--------|
| 1º | **Proteção Principal** | Relé primário da zone afetada — deve atuar primeiro |
| 2º | **Retaguarda Local** | Segundo relé na mesma subestação — falha do principal |
| 3º | **Retaguarda Remota** | Relé em subestação vizinha — backup de backup |

### Retaguarda Remota — Limitações

A proteção de retaguarda remota (relé em outra subestação) tem **tempo de atuação maior** para permitir que a principal atue antes. Porém, quando atua, pode desligar uma área maior do sistema.

### Critério N-1

O sistema deve ser projetado para tolerar a falha de **qualquer componente de proteção único** (relé, disjuntor, TC) sem perda de seletividade.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l08_q1',
        statement: 'Qual é a função da proteção de retaguarda (backup) em um sistema elétrico?',
        options: [
          'Atuar mais rápido que a proteção principal para maior segurança',
          'Substituir a proteção principal em caso de falha desta, garantindo redundância',
          'Monitorar apenas os equipamentos de maior potência',
          'Atuar somente em faltas trifásicas severas',
        ],
        correctIndex: 1,
        explanation: 'A proteção de retaguarda atua caso a principal falhe — seja por falha do relé, do disjuntor ou do sistema de energia do painel. Garante que TODA falta seja eliminada, mesmo com uma falha simples.',
      ),
      TrueFalse(
        id: 'mod02_l08_q2',
        statement: 'O critério N-1 em proteções significa que o sistema deve tolerar a falha de qualquer componente de proteção único sem perda total de seletividade.',
        isTrue: true,
        explanation: 'Correto. O critério N-1 garante que, com a perda de um componente (relé, disjuntor, TC), a proteção de backup seja capaz de isolar o defeito adequadamente.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l09',
    title: 'Tempo de Atuação e Impacto no Sistema',
    subtitle: 'Relação entre velocidade de proteção e estabilidade do sistema',
    content: r'''
## Velocidade da Proteção e Estabilidade

A velocidade de eliminação da falta impacta diretamente a **estabilidade transitória** do sistema:

### Tempo Crítico de Eliminação de Falta (CCT)

O **Critical Clearing Time (CCT)** é o tempo máximo que o sistema tolera com a falta sem perder sincronismo:
- Sistemas de transmissão: CCT tipicamente < 100 ms
- Sistemas de distribuição: CCT menos crítico (geradores distribuídos)

### Consequências do Atraso

```
Tempo de falta < CCT → Sistema mantém estabilidade ✅
Tempo de falta > CCT → Perda de sincronismo, blecaute ❌
```

### Proteções de Alta Velocidade

Para linhas de transmissão críticas, usa-se:
- **Proteção diferencial de linha** (87L): <30 ms típico
- **Proteção de distância com piloto** (POTT/PUTT): <50 ms
- **Proteção de distância Zona 1:** instantânea (~20 ms) para 80-90% da linha
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l09_q1',
        statement: 'O Critical Clearing Time (CCT) representa:',
        options: [
          'O tempo máximo de operação do disjuntor',
          'O intervalo mínimo entre dois desligamentos consecutivos',
          'O tempo máximo que o sistema tolera uma falta sem perder sincronismo',
          'O tempo de recomposição após uma falta eliminada',
        ],
        correctIndex: 2,
        explanation: 'O CCT é o tempo limite: se a falta for eliminada antes do CCT, o sistema mantém estabilidade transitória. Se ultrapassar, os geradores perdem sincronismo.',
      ),
      TrueFalse(
        id: 'mod02_l09_q2',
        statement: 'Em sistemas de transmissão, o Critical Clearing Time é tipicamente inferior a 100 ms, exigindo proteções de alta velocidade.',
        isTrue: true,
        explanation: 'Correto. Em sistemas de transmissão com geradores sincronizados, o CCT pode ser de apenas 50-100 ms, exigindo proteções como diferencial (87L) ou distância com sinalização piloto.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l10',
    title: 'Relés de Sobrecorrente — ANSI 51 e 50',
    subtitle: 'Operação, curvas TCC e aplicação em seletividade',
    content: r'''
## Relés de Sobrecorrente — Funções ANSI 50 e 51

São os relés mais simples e amplamente usados na distribuição:

### Função ANSI 50 — Sobrecorrente Instantâneo
- Atua **instantaneamente** quando a corrente supera o pickup
- Sem intenção de coordenação — para correntes muito elevadas (falta próxima)
- Ajuste típico: 125% a 150% da corrente de curto-circuito mínima da zona

### Função ANSI 51 — Sobrecorrente com Tempo Inverso
- Tempo de atuação **inversamente proporcional** à corrente
- Alta corrente → menor tempo de atuação
- Curvas padronizadas: Normal Inversa, Muito Inversa, Extremamente Inversa

### Curvas TCC (Time-Current Characteristic)

```
Tempo (s)
 ↑
 │╲ Curva do relé de montante
 │ ╲
 │  ╲  ← CTI (intervalo mínimo)
 │   ╲_________________
 │        ╲ Curva do relé de jusante
 └────────────────────→ Corrente (A)
```

A **coordenação** requer que as curvas dos relés em série NÃO se cruzem, mantendo CTI ≥ 0,2 s.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l10_q1',
        statement: 'A função ANSI 51 representa um relé de sobrecorrente com característica:',
        options: [
          'Tempo definido (atraso fixo independente da corrente)',
          'Instantânea (sem atraso)',
          'Tempo inverso (tempo de atuação diminui com o aumento da corrente)',
          'Diferencial (compara correntes de entrada e saída)',
        ],
        correctIndex: 2,
        explanation: 'A função 51 tem característica de tempo inverso: quanto maior a corrente, menor o tempo de atuação. Isso naturalmente favorece a seletividade em sistemas radiais.',
      ),
      TrueFalse(
        id: 'mod02_l10_q2',
        statement: 'A coordenação entre relés de sobrecorrente em série é considerada adequada quando as curvas TCC dos relés NÃO se cruzam e mantêm um CTI mínimo de 0,2 s.',
        isTrue: true,
        explanation: 'Correto. Se as curvas TCC se cruzarem, haverá uma faixa de corrente onde o relé a montante atua antes do a jusante, perdendo seletividade.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_l11',
    title: 'Proteção de Retaguarda Remota em Sistemas de Transmissão',
    subtitle: 'Função ANSI 21 como backup de linhas adjacentes',
    content: '## Em desenvolvimento\n\nConteúdo: Retaguarda de distância, Zona 3 como backup remoto, limitações de infeed.',
    questions: [],
  ),
  Lesson(
    id: 'mod02_l12',
    title: 'Revisão Geral — Módulo 02',
    subtitle: 'Consolidação: Filosofia, Zonas e Seletividade',
    content: r'''
## Revisão: Módulo 02 — Pontos Essenciais

### Objetivo da Proteção
- Isolar **apenas** o elemento com defeito
- Equilibrar: **Sensibilidade × Velocidade × Seletividade**

### Zonas de Proteção
- Delimitadas em torno de componentes: barras, TFs, linhas, geradores
- Devem se **sobrepor** nos disjuntores (sem zonas mortas)
- Falta no overlap → ambas as zonas desarmam

### Tipos de Seletividade
- **Amperimétrica:** Diferença de corrente; requer alta impedância entre estágios (TF)
- **Cronométrica:** Atrasos escalonados; CTI = 0,2 a 0,4 s
- **Lógica:** Comunicação entre relés; atuação instantânea em qualquer zona

### Proteção Principal vs. Backup
- Sempre redundante (N-1)
- Retaguarda local > Retaguarda remota (velocidade)

### Relés e Funções ANSI
- **50:** Instantâneo; **51:** Tempo inverso; **21:** Distância
    ''',
    questions: [
      MultipleChoice(
        id: 'mod02_l12_q1',
        statement: 'Qual tipo de seletividade usa comunicação entre relés para garantir atuação instantânea em qualquer ponto do sistema?',
        options: ['Amperimétrica', 'Cronométrica', 'Lógica', 'Diferencial'],
        correctIndex: 2,
        explanation: 'A seletividade lógica usa sinais de comunicação (bloqueio) entre relés, eliminando a necessidade de atrasos de tempo e permitindo atuação instantânea.',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════
  //  AVALIAÇÕES (2)
  // ══════════════════════════════════════════════════════════════

  Lesson(
    id: 'mod02_eval1',
    title: 'Avaliação 1 · Zonas de Proteção e Seletividade',
    subtitle: 'Conceitos de zonas, overlap e tipos de seletividade',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod02_eval1_q1',
        statement: 'Por que as zonas de proteção devem se sobrepor nos disjuntores?',
        options: [
          'Para aumentar a velocidade dos relés',
          'Para garantir que nenhuma parte do sistema fique sem proteção (sem zonas mortas)',
          'Para permitir que dois relés atuem simultâneos em qualquer falta',
          'Para reduzir o custo dos disjuntores',
        ],
        correctIndex: 1,
        explanation: 'O overlap garante cobertura total. Sem ele, os disjuntores de fronteira estariam em "zonas mortas" sem proteção associada.',
      ),
      MultipleChoice(
        id: 'mod02_eval1_q2',
        statement: 'Qual tipo de seletividade é MAIS adequado quando existe um transformador de alta relação de transformação entre os estágios de proteção?',
        options: ['Lógica', 'Cronométrica', 'Diferencial', 'Amperimétrica'],
        correctIndex: 3,
        explanation: 'O transformador cria uma grande diferença nos níveis de corrente de curto entre o primário e o secundário, tornando a seletividade amperimétrica altamente eficaz.',
      ),
      TrueFalse(
        id: 'mod02_eval1_q3',
        statement: 'O CTI (Intervalo de Coordenação de Tempo) de 0,2 a 0,4 s é necessário para compensar o tempo de abertura do disjuntor e o overshoot do relé.',
        isTrue: true,
        explanation: 'Correto. O CTI deve acomodar: tempo de abertura do disjuntor (até 0,10 s), overshoot do relé (0,05-0,10 s) e margem de segurança, totalizando 0,20-0,40 s.',
      ),
      MultipleChoice(
        id: 'mod02_eval1_q4',
        statement: 'Na seletividade lógica, quando o relé a montante RECEBE o sinal de bloqueio do relé a jusante, ele deve:',
        options: [
          'Atuar imediatamente',
          'Aguardar — a falta está na zona do relé a jusante que já atuará',
          'Bloquear também o relé a jusante',
          'Enviar confirmação de bloqueio para o relé gerador',
        ],
        correctIndex: 1,
        explanation: 'O sinal de bloqueio indica que o relé a jusante detectou a falta em sua zona e irá atuar. O relé a montante aguarda e só atua se o a jusante falhar.',
      ),
    ],
  ),

  Lesson(
    id: 'mod02_eval2',
    title: 'Avaliação Final · Módulo 02',
    subtitle: 'Avaliação integrada de filosofia e seletividade',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod02_eval2_q1',
        statement: 'Os três parâmetros que devem ser equilibrados em um sistema de proteção elétrica são:',
        options: [
          'Corrente, tensão e frequência',
          'Sensibilidade, velocidade e seletividade',
          'Impedância, tempo e corrente de pickup',
          'Zona 1, Zona 2 e Zona 3',
        ],
        correctIndex: 1,
        explanation: 'O trinômio da proteção é Sensibilidade × Velocidade × Seletividade. Melhorar um parâmetro geralmente afeta os outros, exigindo equilíbrio no projeto.',
      ),
      TrueFalse(
        id: 'mod02_eval2_q2',
        statement: 'A proteção de retaguarda remota, por ter maior tempo de atuação, pode desligar uma área maior do sistema do que a proteção principal.',
        isTrue: true,
        explanation: 'Correto. A retaguarda remota (em outra subestação) deve esperar mais tempo para garantir que a principal atue primeiro. Quando opera, isola sua zona inteira, que é maior.',
      ),
      MultipleChoice(
        id: 'mod02_eval2_q3',
        statement: 'A função ANSI 50 representa um relé de:',
        options: [
          'Sobrecorrente com tempo inverso',
          'Sobrecorrente instantâneo',
          'Distância (impedância)',
          'Proteção diferencial',
        ],
        correctIndex: 1,
        explanation: 'A função ANSI 50 é o relé de sobrecorrente instantâneo — atua imediatamente quando a corrente supera seu pickup, sem atraso de tempo intencional.',
      ),
      FillInTheBlanks(
        id: 'mod02_eval2_q4',
        statement: 'Complete sobre os tipos de seletividade:',
        textWithBlanks: 'A seletividade ____ usa diferença de níveis de corrente. A ____ usa atrasos de tempo escalonados. A ____ usa comunicação entre relés.',
        blanks: [
          Blank(index: 0, answer: 'amperimétrica'),
          Blank(index: 1, answer: 'cronométrica'),
          Blank(index: 2, answer: 'lógica'),
        ],
        explanation: 'Cada tipo de seletividade usa um princípio diferente: magnitude de corrente (amperimétrica), tempo (cronométrica) ou comunicação (lógica).',
      ),
    ],
  ),
];
