import 'package:spark_app/models/quiz_models.dart';

// ─────────────────────────────────────────────────────────────────
//  BLOCO 1 — MÓDULO 01: Fundamentos e Ferramentas Analíticas
//  Sistema Por Unidade (PU) e Componentes Simétricas
//  20 Lições + 4 Avaliações
// ─────────────────────────────────────────────────────────────────

final List<Lesson> mod01Lessons = [
  // ══════════════════════════════════════════════════════════════
  //  BLOCO A: SISTEMA POR UNIDADE (Lições 1–10)
  // ══════════════════════════════════════════════════════════════

  Lesson(
    id: 'mod01_l01',
    title: 'Introdução ao Sistema Por Unidade (PU)',
    subtitle: 'Conceito, propósito e vantagens da normalização',
    content: r'''
## O que é o Sistema Por Unidade?

O **Sistema Por Unidade (PU)** expressa as grandezas elétricas (tensão, corrente, potência, impedância) como frações adimensionais de um **valor base predefinido**.

$$X_{PU} = \\frac{X_{real}}{X_{base}}$$

### Por que usar o Sistema PU?

Em sistemas de potência com **múltiplos níveis de tensão** interconectados por transformadores, o PU elimina a necessidade de contabilizar as relações de espiras nos cálculos de impedância.

**Vantagens práticas:**
- Simplifica cálculos em redes com transformadores
- Facilita a comparação entre equipamentos de fabricantes diferentes
- Reduz erros de conversão entre diferentes níveis de tensão
- Grandezas PU de equipamentos similares ficam na mesma faixa (~0,05 a 0,20 pu)

> ⚡ Em estudos de proteção e estabilidade, o sistema PU é a linguagem universal dos engenheiros de sistemas de potência.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l01_q1',
        statement: 'Qual é o principal objetivo de um sistema de proteção de energia em relação ao fornecimento de eletricidade?',
        options: ['Garantir que a conta de luz venha mais barata', 'Minimizar a interrupção do fornecimento isolando rapidamente o defeito', 'Aumentar a tensão em horários de pico', 'Desligar a energia sempre que chover forte'],
        correctIndex: 1,
        explanation: 'A meta nº 1 é manter a rede operando. Identificar e isolar APENAS o trecho com defeito garante energia para o resto do sistema!',
      ),
      MultipleChoice(
        id: 'mod01_l01_q2',
        statement: 'O que pode acontecer com o sistema elétrico se uma falha não for isolada rapidamente pelos equipamentos de proteção?',
        options: ['Equipamentos suportam curtos infinitamente', 'Causa instabilidade em cascata, incêndios e danos irreversíveis aos ativos primários', 'Apenas uma oscilação leve na tensão', 'A rede se autoconserta gradativamente'],
        correctIndex: 1,
        explanation: 'Faltas não tratadas viram uma bola de neve: os equipamentos derretem, a estabilidade cai, e ocorre o famoso blecaute em cascata!',
      ),
      MultipleChoice(
        id: 'mod01_l01_q3',
        statement: 'Como a norma IEC 60255-20 define um "Sistema de Proteção"?',
        options: ['Um arranjo de um ou mais equipamentos de proteção integrados para realizar uma função específica', 'Apenas o disjuntor de alta tensão', 'Um software de simulação digital', 'Toda a fiação de aterramento'],
        correctIndex: 0,
        explanation: 'A IEC define o "sistema" como o pacote completo integrado: relés, TCs, TPs, fiação e baterias necessários para detectar e atuar na falta.',
      ),
      TrueFalse(
        id: 'mod01_l01_q4',
        statement: 'O "Equipamento de Proteção" é o hardware individual (ex: um relé), enquanto o "Esquema de Proteção" abrange a coordenação conjunta de múltiplos equipamentos interagindo no sistema.',
        isTrue: true,
        explanation: 'O equipamento é o dispositivo inteligente, mas o Esquema (Scheme) engloba a colaboração lógica sistêmica entre eles (teleproteção, intertravamentos, etc).',
      ),
      MultipleChoice(
        id: 'mod01_l01_q5',
        statement: 'Quais são as consequências econômicas e operacionais de não fornecer proteção adequada aos equipamentos primários do sistema?',
        options: ['Destruição de ativos milionários, multas regulatórias e longos apagões', 'As contas de energia ficam pendentes', 'Redução ligeira na eficiência do transformador', 'Um simples rearme manual do operador resolve tudo'],
        correctIndex: 0,
        explanation: 'Danos em ativos vitais (ex: transformador base) paralisam a economia e sua reposição dura de meses a anos. A proteção atua fechando a porta antes do estrago!',
      ),
      MultipleChoice(
        id: 'mod01_l01_q6',
        statement: 'Em que princípio se baseia a métrica de "desempenho estatístico" utilizada para avaliar a confiabilidade de esquemas de proteção?',
        options: ['Custo total da aquisição dos relés em dólar', 'Análise histórica da razão de atuações corretas divididas pelo total (atuações certas + falhas + falso trips)', 'Gasto energético do equipamento por ano', 'A quantidade de relatórios gerados por defeito'],
        correctIndex: 1,
        explanation: 'O desempenho de longo prazo (Reliability) no mundo real é calculado pelas métricas estatísticas: a proporção de vezes em que a proteção acertou e os raros vacilos.',
      ),
      MultipleChoice(
        id: 'mod01_l01_q7',
        statement: 'Por que as redes de distribuição elétrica tipicamente NÃO requerem sistemas de proteção de altíssima velocidade (instantâneos) em toda a sua extensão, diferentemente das super-redes EHV?',
        options: ['Redes de distribuição usam cabos mais modernos e finos', 'Porque a tensão menor gera curtos de menor intensidade energética que não causam perda imediata de sincronismo na rede continental', 'A distribuição atende a clientes menos importantes', 'Relés rápidos não cabem em postes urbanos'],
        correctIndex: 1,
        explanation: 'Enquanto uma linha de 500 kV pode derrubar meio continente em instantes, uma rede de 13,8 kV normalmente tem curtos menores e sua demora afeta estritamente o ambiente local, não o sincronismo nacional.',
      ),
      MultipleChoice(
        id: 'mod01_l01_q8',
        statement: 'Quais são as duas principais categorias em que as operações incorretas e problemáticas dos relés podem ser classificadas?',
        options: ['Amarelo e Vermelho (Graus de urgência)', 'Mecânica e de Software', 'Falha ao atuar (Failure to trip) e Operação indevida/espúria (False/Over-trip)', 'Curto-circuito interno e Falha de calibração'],
        correctIndex: 2,
        explanation: 'Os dois grandes pesadelos da engenharia de proteção: cruzar os braços na hora que a rede queima (Failure to Trip) e enxergar fantasmas ativando disjuntores à toa (False Trip).',
      ),
      MultipleChoice(
        id: 'mod01_l01_q9',
        statement: 'De que forma a introdução de redundância (configuração Main-1 + Main-2) afeta a probabilidade final de falha de um esquema de proteção num sistema elétrico vital?',
        options: ['Deixa o painel elétrico o dobro do tamanho mas não ajuda em nada', 'Aumenta significativamente a probabilidade de "Acerto" (Dependability), mitigando pontos únicos de falha', 'Reduz muito a rapidez do disparo (Trip)', 'Gera instabilidade por concorrência entre relés'],
        correctIndex: 1,
        explanation: 'Dobrar a segurança! Em sistemas super críticos, duas fileiras paralelas de proteção reduzem o risco de omissão a valores quase nulos (Aumenta a Dependabilidade).',
      ),
      MultipleChoice(
        id: 'mod01_l01_q10',
        statement: 'O que significa a estratégia lógica de disparo "um de dois" (one-out-of-two) típica em esquemas redundantes?',
        options: ['Um relé quebra e o outro entra como backup em algumas horas', 'Basta que QUALQUER UM dos dois relés detecte a falta para enviar o Trip geral, maximizando a certeza térmica de limpar a falta (Dependability)', 'Dois relés precisam obrigatoriamente concordar juntos para disparar', 'Apenas 50% dos disjuntores podem ser ativados simultaneamente'],
        correctIndex: 1,
        explanation: 'Arranjo clássico 1-de-2 (1oo2): qualquer relé que identificar defeito "grita" sozinho e age imediatamente em via paralela, priorizando fortemente a proteção (mas mais vulnerável a falsos-trips).',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l02',
    title: 'Grandezas Base — Potência e Tensão',
    subtitle: 'Seleção de Sbase e Vbase em um sistema',
    content: r'''
## Como Escolher as Grandezas Base?

Em um estudo típico de sistema de potência, o engenheiro escolhe:

### Base de Potência (S_base)
- **Uma única base de potência** para todo o sistema (trifásica)
- Valores típicos: 100 MVA, 1000 MVA (múltiplos convenientes)
- Permanece constante em todas as regiões do sistema

### Base de Tensão (V_base)
- **Uma base de tensão por região** (separada pelos transformadores)
- Escolhida como a tensão nominal da região
- As outras regiões são determinadas pela relação de transformação

### Grandezas Base Derivadas

A partir de S_base e V_base (sistema trifásico):

| Grandeza | Fórmula |
|----------|---------|
| Corrente base | $I_{base} = \\frac{S_{base}}{\\sqrt{3} \\cdot V_{base}}$ |
| Impedância base | $Z_{base} = \\frac{V_{base}^2}{S_{base}}$ |
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l02_q1',
        statement: 'O que é o Sistema Por Unidade (PU) e por que ele é vital na análise de redes com múltiplos níveis de tensão?',
        options: [
          'É um sistema que reduz correntes de curto para apenas 1 ampere',
          'É a representação de valores elétricos como decimais referidos à uma base comum, eliminando a complicação das relações de variação num transformador',
          'Garante tensão de 220V linear na fase residencial sempre',
          'Representa matrizes de transição estáticas de sistemas contínuos',
        ],
        correctIndex: 1,
        explanation: 'Ao "escalar" as coisas para limites como 0,8PU e 1,2PU com Base fixa conectada entre os trafos, os cálculos complexos fluem sem tropeços em diferentes tensões kV.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q2',
        statement: 'Qual equação matemática geral converte uma impedância da sua "base de placa" do fabricante para a nova Base Geral de PU do Estudo?',
        options: [
          'Z_{novo} = Z_{antigo} × (S_{modificado} / S_{placa}) × (V_{placa} / V_{modificado})²',
          'Z_novo = R_novo² / X_antiga',
          'Apenas dividimos por 0.8 de segurança elétrica',
          'Subtraímos os valores P e Q ativos'
        ],
        correctIndex: 0,
        explanation: 'Regra de ouro: A impedância P.U. sobe e desce proporcionalmente com a nova Potência, e com o fator ao quadrado das bases de voltagem modificadas.',
      ),
      TrueFalse(
        id: 'mod01_l02_q3',
        statement: 'O teorema de Componentes Simétricas de Fortescue permite decompor um complexo cenário desequilibrado em sistemas simples 3-fásicos individuais independentes para modelar Faltas no cálculo vetorial.',
        isTrue: true,
        explanation: 'Simétrico! É graças às ideias de 1918 de Fortescue que a proteção consegue analisar perfeitamente os efeitos bizarros e caóticos de correntes num curto linha-terra ou curto bifásico.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q4',
        statement: 'Quais são as três componentes de sequência em que um sistema CA trifásico desequilibrado é matematicamente decomposto?',
        options: ['Vermelha, Azul e Amarela', 'Maior Média e Baixa', 'Positiva (I1), Negativa (I2) e Zero (I0)', 'Tangencial Transversal e Transiente'],
        correctIndex: 2,
        explanation: 'I1 (Funcionamento Positivo Rotativo), I2 (Anormal Rotação Reversa), e I0 (Em fase na ausência de rotação-comum). O tripé da proteção moderna.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q5',
        statement: 'Como se configura o arranjo de rotação e ângulos de defasagem dos três vetores fasoriais correspondentes à Componente "Seq. Positiva (I1)"?',
        options: [
          'Os vetores coincidem no msm local no ângulo paralelo do solo e rodam inversos',
          'Iguais entre si defasados a exatos 120° formando rotação normal clássica A-B-C do sentido horoscópico',
          '180 Graus simetricamente defasados nas linhas com neutro reverso',
          'Eles apenas possuem rotação de 360 Graus paralela sem repetição.'
        ],
        correctIndex: 1,
        explanation: 'A Seq. Positiva simula fisicamente o estado da planta ideal e harmônico, os fasores iguais com defasagem redonda de 120 na ordem A,B,C natural.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q6',
        statement: 'Em qual tipo específico de falta elétrica modelada via redes de componentes de sequência as matrizes encontram-se conectadas plenamente "EM SÉRIE" durante a análise?',
        options: ['Falta 3-Fásica Perfeita', 'Curto Bifásico comum s/terra', 'Falta Monofásica Linha-Terra', 'Curto Circuito em Duplo Trafo Estrela-Triangulo'],
        correctIndex: 2,
        explanation: 'Curto Mono/Linha-Terra joga todo mundo na roda! A matriz manda que as Redes de Seq +, - e 0 se unam EM SÉRIE no cálculo para somarem fluxos idênticos!',
      ),
      MultipleChoice(
        id: 'mod01_l02_q7',
        statement: 'O surgimento intenso de componentes da chamada Sequência Negativa (I2) na linha elétrica de campo representa essencialmente qual condição física ocorrendo?',
        options: ['Dreno para solo e fluxos de dispersão terra', 'Desequilíbrios não-aterraáveis significativos por assimetrias extremas na rede elétrica ligando correntes contra a ordem harmônica', 'Aumento drástico de energia Reativa Limpa', 'Corte instantâneo nas perdas Tèrmicas'],
        correctIndex: 1,
        explanation: 'I2 aparece sempre que a perfeitamente sinagoga balança das Fases é quebrada ou desequilibrada bruscamente, gerando atritos térmicos nos rotores e anomalias nas linhas sem envolver necessariamente o aterramento neutro.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q8',
        statement: 'Caso utilizemos um clássico Transformador D-Yn (Delta frente Estrela-Aterrada), como ele atua perante o avanço da Componente Sec. ZERO da rede?',
        options: ['Aumenta a sec-Zero nas fiações para ambos os caminhos do relé', 'Permite do lado da Estrela correr a terra mas a trava na bobina em formato Delta gerando um bloqueio ou "armadilha interna" não espalhando', 'O Trafo imediatamente derrete sob esse impacto vetorial', 'Não afeta a sec-Zero e passa tudo como vidro transparente'],
        correctIndex: 1,
        explanation: 'Uma autêntica prisão elétrica de corrente Sec Zero. No lado conectado como "Y-Terra", ela tem o caminho limpo de passagem, porem, ao chegar no trafo modelo "Delta/Triangulo", ela não consegue sair pro lado primario rodando ciclicamente livre apenas "presa" ali.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q9',
        statement: 'Por que o fluxo da "Corrente Subtransitória" de curto é estipulada e utilizada sempre no dimensionamento e sensibilidade imediata dos relés num painel?',
        options: ['Pois gera menores custos nos cabos do local de aplicação elástico', 'Ela mostra valores atenuados suaves', 'Ela é o espelho exato imediato do primeiro e violento ciclo e da máxima energia térmica agressora da Falta', 'Exigência apenas de estética e burocracia dos cálculos'],
        correctIndex: 2,
        explanation: 'Os Relés atuam em tempos ridículos de milisegundos! Por causa disso, só aquela explosão brutal do 1° ao 3° ciclo (A.k.A Sub-Transitória de corrente inicial) da máquina reflete o que o TC e o Relé engolem primeiro.',
      ),
      MultipleChoice(
        id: 'mod01_l02_q10',
        statement: 'De qual maneira técnica e empírica a razão (Relação X/R - Reatância por Resistência) pode estragar a vida dos disjuntores da subestação no instante da falta?',
        options: ['Ao gerar assimetria de "Corrente DC de Offset" muito duradouras, somando uma super-elevação momentânea no momento de corte do disjuntor', 'Pelo aumento na resistência em si estourando o calor global em graus Celsius bruscamente nos polos da rede', 'Criando harmônicos pares apenas nas redes', 'O disjuntor rejuvesnesce quanto maior o peso X/R'],
        correctIndex: 0,
        explanation: 'Sistemas que ficam perto da geração têm taxa de indutância pesadíssima contra o balanço resistivo de perdas. Um X/R monstruoso joga no colo da corrente uma onda "Offset Contínua temporária" (onda alta desbalanceada torta fora do zero) no momento do choque prejudicando muito mais o interruptor para desarmar.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l03',
    title: 'Conversão de Impedâncias Entre Bases',
    subtitle: 'Adequação de dados do fabricante para a base do estudo',
    content: r'''
## Convertendo Impedâncias de Uma Base Para Outra

Fabricantes fornecem impedâncias na **base própria do equipamento**. Para um estudo de sistema, é necessário convertê-las para a **base geral do sistema**.

### Fórmula de Conversão

$$Z_{PU,novo} = Z_{PU,antigo} \\times \\frac{S_{base,novo}}{S_{base,antigo}} \\times \\left(\\frac{V_{base,antigo}}{V_{base,novo}}\\right)^2$$

### Exemplo Prático

Um transformador de 30 MVA, 138/13,8 kV tem impedância de 0,10 PU na sua própria base.

**Dados do sistema:** S_base = 100 MVA, V_base = 138 kV (lado AT)

$$Z_{PU,sistema} = 0{,}10 \\times \\frac{100}{30} \\times \\left(\\frac{138}{138}\\right)^2 = 0{,}333 \\ PU$$

> 💡 Quando as tensões nominais coincidem com as bases do sistema, o fator de tensão é igual a 1 e simplifica o cálculo.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l03_q1',
        statement: 'O que são as zonas de proteção e quais equipamentos elas geralmente englobam?',
        options: ['Áreas geográficas da cidade', 'Regiões elétricas delimitadas por TCs que englobam e protegem um equipamento primário específico (Trafo, Linha, Barras)', 'As zonas de segurança para operadores das subestações', 'Limites de dissipação de calor dos geradores'],
        correctIndex: 1,
        explanation: 'O sistema elétrico é fatiado em "Zonas de Proteção". Cada equipamento nobre ganha a sua bolha de proteção individual delimitada pelos TCs!',
      ),
      TrueFalse(
        id: 'mod01_l03_q2',
        statement: 'É absolutamente essencial que as bordas (limites) das zonas de proteção sempre se sobreponham umas às outras abrangendo o disjuntor para que nunca existam "pontos cegos" na malha.',
        isTrue: true,
        explanation: 'Sem essa sobreposição (overlap), um curto físico no pé do disjuntor seria invisível para os relés e fritaria a rede inteira. Sobreposição é segurança primária!',
      ),
      MultipleChoice(
        id: 'mod01_l03_q3',
        statement: 'O que ocorre de fato caso um curto-circuito incida cirurgicamente bem na pequena malha de sobreposição (overlap) entre as duas zonas de proteção principais?',
        options: ['Ambas as zonas de proteção enviam Trip, abrindo disjuntores de dois equipamentos ao invés de um. É o preço para não haver pontos cegos.', 'Nenhum dos relés atua e o curto é ignorado preventivamente', 'Ocorre um curto-circuito interno que derrete o TC de interface', 'Apenas a Zona A manda o trip deixando a Zona B em espera infinita'],
        correctIndex: 0,
        explanation: 'Sendo uma região compartilhada, os dois relés percebem o defeito e disparam todos os disjuntores envolvidos. Cai mais carga que o esperado, mas extingue a falta instantaneamente.',
      ),
      MultipleChoice(
        id: 'mod01_l03_q4',
        statement: 'Defina o conceito chave e mestre da Seletividade de Proteção e como ela funciona.',
        options: ['É a tecnologia dos disjuntores cortarem o arco', 'A capacidade do sistema de escolher SEMPRE atuar todos os relés da árvore para garantir redundância e apagar geral', 'A arte de isolar estritamente o trecho problemático mantendo todo o resto da instalação com energia vital sem causar um colapso-apagão generalizado', 'Relés digitais se comunicando apenas via fibra ótica ao invez de cabos metálicos cruzados'],
        correctIndex: 2,
        explanation: 'Seletividade é o maestro: quem estiver mais perto do incêndio, apaga-o. Os relés de cima esperam e observam, para manter o mínimo possível de consumidores desligados.',
      ),
      MultipleChoice(
        id: 'mod01_l03_q5',
        statement: 'Como opera teoricamente a chamada "Seletividade Amperimétrica" e qual peça essencial da rede auxilia dramaticamente o seu alcance e uso confiável?',
        options: ['O Relé de montante reverte fases do queimar em paralelo e o Transformador dissipa isso em calor', 'Funciona com correntes puramente fixas, independe da impedância global', 'Ampara-se na diferença gigante de curto se houver muita impedância entre as subestações, o que é muito favorecido pela presença de grandes Transformadores entre elas', 'É uma tecnologia abandonada em 1920'],
        correctIndex: 2,
        explanation: 'Se houver um Trafo (gigante muro de impedância) entre A e B, a diferença da corrente de falta é drástica! Ajusta o relé em amperes e ele nunca enxerga falsamente a outra zona!',
      ),
      MultipleChoice(
        id: 'mod01_l03_q6',
        statement: 'A Seletividade Cronométrica ou proteção Temporizada usa qual premissa básica e atraso de margem clássico como padrão ouro de ajuste escalonado?',
        options: ['Tempos aleatórios de 5 a 10 segundos para preservar disjuntores da queima do arco voltaico', 'Tempo e corrente fixos, sem margem', 'Pura coordenação de tempo de espera. Quem está mais longe da fonte espera um degrau clássico entre 0.2s e 0.4s para só atuar depois do relé titular de jusante!', 'Pura coordenação de corrente no disparo inicial da Sub-Transitória sem espera (milisegundos apenas)'],
        correctIndex: 2,
        explanation: 'O relé do retaguarda pensa: "Deu curto! Vou esperar calmamente de 0.2s a 0.4s. Se o relé dele falhar ou o Disjuntor engasgar, eu dou Trip e desligo tudo aqui atrás!".',
      ),
      MultipleChoice(
        id: 'mod01_l03_q7',
        statement: 'Num esquema top-tier logico moderno (Seletividade Lógica com Intertravamento), o que acontece quando o relé alimentador e o relé principal identificam a falta ao msm tempo?',
        options: ['Disparam a torre', 'Disputam acesso logico por rede de ethernet local', 'O Relé da frente envia um grito digital um BLOQUEIO (Block) na fiação do Relé Principal de trás do tipo: "Guenta aí grandão, o curto é aqui na frente, já to atirando no desjuntor!!"', 'O Relé secundário sempre atua com o primeiro e só depois tentam religar sequencial da fiação'],
        correctIndex: 2,
        explanation: 'No exato milissegundo de identificação, o relé próximo emite sinal de Bloqueio para estabilizar a mente do disjuntor de Retaguarda, eliminando a demora do "Esperar por tempo" da cronométrica!',
      ),
      TrueFalse(
        id: 'mod01_l03_q8',
        statement: 'A atuação de um relé Proteção de Retaguarda (Backup) sempre afeta mais carga (desliga mais clientes e equipamentos) do que a atuação da Proteção Primária.',
        isTrue: true,
        explanation: 'Por ficar na base do funil da Subestação, o Back-up isola todo o barramento derrubando indiscriminadamente todas as saídas no processo. Uma segurança fatal necessária no pior dos casos.',
      ),
      MultipleChoice(
        id: 'mod01_l03_q9',
        statement: 'Se dissermos que um sistema usa "Proteção de Unidade" (Unit Protection) de atuação principal (como proteção Diferencial), qual é a sua principal virtude técnica e característica?',
        options: ['Pode esperar vários segundos ajustando corrente seletiva em lógicas', 'É totalmente surdo aos curtos-circuitos fora da sua bolha de unidade, permitindo um disparo "zero segundos" instantâneo ABSOLUTO de puríssima seletividade dentro dela!', 'Trabalha unifica as correntes e reatâncias por meio magnético global', 'Ele funde todos os polos térmicos unindo os barramentos próximos'],
        correctIndex: 1,
        explanation: 'A Proteção Diferencial e Similares Unitárias não "veem" o que acontece com a rede global, elas só cuidam dos seus domínios exclusivos. Se falhar dentro é TRIP FULMINANTE e MÁXIMO imediato!',
      ),
      MultipleChoice(
        id: 'mod01_l03_q10',
        statement: 'No dialeto de campo da Proteção, o que significa um Relé Diferencial ou similar possuir altíssima "Estabilidade"?',
        options: ['O painel frontal metálico não amassa facilmente com batidas', 'Significa que o relé possui a nobre característica de ignorar calmamente e PERMANECER de braços abaixados perante FALTAS EXTERNAS pesadas varando sua malha sem errar o pulso e disparar em falso', 'Tem imunidade a poeira e ao som do sistema de ar condicionado quebrando as resinas', 'Consegue ligar e calibrar de maneira rápida sem reiniciar no sistema scada'],
        correctIndex: 1,
        explanation: 'Um relé 87 ESTÁVEL é aquele guerreiro frio: vê o "Mundo pegando fogo" num curto vizinho com 20 Mil Amperes passando nos seus cabos... mas cruza os braços pois sabe que a culpa não é do seu equipamento focado!',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l04',
    title: 'Aplicação PU em Curto-Circuito Trifásico',
    subtitle: 'Cálculo de correntes de falta em sistema PU',
    content: r'''
## Cálculo de Curto-Circuito Usando PU

O sistema PU simplifica enormemente os cálculos de curto-circuito em redes complexas.

### Procedimento

1. **Selecionar bases:** Sbase e Vbase para cada região
2. **Converter all impedâncias** para a base do sistema
3. **Montar o circuito equivalente** Thevenin na barra de falta
4. **Calcular corrente de falta:**

$$I_{falta,PU} = \\frac{V_{PU}}{Z_{Thevenin,PU}}$$

Para tensão pré-falta de 1,0 PU:

$$I_{falta,PU} = \\frac{1{,}0}{Z_{Thevenin}}$$

5. **Converter para amperes:**

$$I_{falta,A} = I_{falta,PU} \\times I_{base}$$

### Falta Trifásica — Caso Mais Simples

A falta trifásica balanceada utiliza apenas a **rede de sequência positiva** (máxima corrente de falta), sendo o pior caso para dimensionamento de disjuntores.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l04_q1',
        statement: 'Qual é o papel central dos Transformadores de Corrente (TCs) e de Potencial (TPs) na operação dos Relés de Proteção Inteligentes (IEDs)?',
        options: ['Gerar energia extra para bateria', 'Reduzir as massivas correntes e tensões primárias da rede para níveis minúsculos (ex: 5A e 115V) perfeitamente proporcionais, atuando como "os olhos" do Relé', 'Filtrar ruídos de rádio UHF', 'Atuar como disjuntores auxiliares de trip'],
        correctIndex: 1,
        explanation: 'Os IEDs são computadores sensíveis de 5 Volts. TCs e TPs são os transdutores brutos que traduzem a ira dos 500 kV e 10.000 A para valores que o relé consegue processar a salvo no painel.',
      ),
      MultipleChoice(
        id: 'mod01_l04_q2',
        statement: 'Como deve ser a resposta do núcleo magnético de um TC de "Proteção" durante correntes de falta de magnitude brutal, em comparação a um TC de medição comercial?',
        options: ['Ambos reagem iguais quebrando após 10A', 'TCs Comerciais não saturam nunca. O de proteção satura fácil', 'TCs de Proteção usam núcleo gigantesco e saturam O MAIS TARDE POSSÍVEL para conseguir reproduzir correntes extremas fielmente ao relé (20x a Inominal)', 'TCs de Proteção devem atuar cortando o sinal imediatamente ao sinal do surto'],
        correctIndex: 2,
        explanation: 'O TC de faturamento (medição) satura de propósito nas faltas pra salvar o medidor. Já o herói da Proteção precisa continuar refletindo os 20.000 Amperes do curto sem "cegar" o Relé (saturar)',
      ),
      TrueFalse(
        id: 'mod01_l04_q3',
        statement: 'A "Tensão de Saturação" ou Knee Point Voltage (Vk) de um TC marca o ponto onde aplicar 10% a mais de tensão na bobina exige um aumento de absurdos 50% de corrente de excitação, provando a fadiga magnética.',
        isTrue: true,
        explanation: 'Knee Point é o "Joelhaço" da Curva! A partir deste ponto crítico de magnetização o Ferro do núcleo espreme seu limite e o TC já não consegue enviar a corrente correta ao relé (Ele fica CEGO).',
      ),
      MultipleChoice(
        id: 'mod01_l04_q4',
        statement: 'Quais são os dois tipos fundamentais de transformadores voltados à medição e reprodução fiel de tensão nas subestações elétricas?',
        options: ['Indutivos (Bobinas acopladas em Ferro) e Capacitivos (Divisores usando capacitores de AT)', 'Estrela direta e Triangulo fantasma', 'Eletrônicos Wifi e Ultrassônicos', 'Subterraneos e Áereos de linha'],
        correctIndex: 0,
        explanation: 'Temos os TPs Indutivos clássicos (Ferro e Cobre puros) e os CVTs ou TPCs usados largamente em 230kV pra cima, que cortam a tensão em série primeiro usando torres de capacitores!',
      ),
      MultipleChoice(
        id: 'mod01_l04_q5',
        statement: 'Que grave risco de instabilidade CAÓTICA está atrelado ao uso de TPs se os mesmos não possuírem sistemas de amortecimento ou resistores de carga próprios adequados?',
        options: ['Roubo massivo de dados do fabricante', 'O temido efeito Ferrorressonância, onde capacitâncias parasitas e a indutância do TP entram em dança de ressonância injetando sobretensões letais ou quebrando isolamentos', 'Efeito Corona reverso', 'Vibração subsíncrona mecânica dos cabos'],
        correctIndex: 1,
        explanation: 'A Ferroressonância destrói o papel e óleo isolante causando queima repentina em minutos. Para evitar, injeta-se Resistores Pesados em secundários abertos do VT.',
      ),
      MultipleChoice(
        id: 'mod01_l04_q6',
        statement: 'Por que o Transformador de Potencial Capacitivo (CVT) ganha a briga e é frequentemente priorizado e dominante em aplicações de extra-alta-tensão (EHV) tipo 500kV?',
        options: ['Por ser muito mais leve', 'Por causa do custo de isolação altíssimo, CVTs custam muito mais barato em Alta Tensão e ainda permitem plugar Carrier (PLC) para Telecom!', 'Porque CVTs nunca sofrem fadiga transitória', 'Porque eles têm núcleos maiores de Ouro'],
        correctIndex: 1,
        explanation: 'Construir trafo indutivo de bobinas de cobre suportando 500 Mil Volts sem furar o papel é financeiramente inviável. As pilhas TPC e os capacitores resolvem melhor - e você ganha "Onda Portadora" de brinde!',
      ),
      TrueFalse(
        id: 'mod01_l04_q7',
        statement: 'Os TPs Capacitivos geram problemas conhecidos como Subsidence Transients: quando ocorre uma falta pesada e a tensão zera, a energia presa nos capacitores "treme" a leitura de decaimento para o relé confundindo e piorando funções como a Zona 1 de Distância.',
        isTrue: true,
        explanation: 'Perfeito. Um "zumbido mortal" transitório confunde a memória direcional dos Relés (Distance ANSI 21). Eles acham que o defeito pode estar longe ou perto por causa das descargas indesejadas LC do TPC!',
      ),
      MultipleChoice(
        id: 'mod01_l04_q8',
        statement: 'Das quais grandezas físicas se compõe a popular fórmula do Burden, a dita e associada carga do circuito secundário "das costas" do TC?',
        options: ['Velocidade da luz dividida pelo tempo', 'Da resistência total da fiação somada à impedância de entrada do Relé multiplicados logicamente ou somados até o Painel (Corrente x Corrente x Z em VA)', 'Volt-Amperes multiplicados por RPM do Painel', 'Resistência de fuga terra isolada apenas'],
        correctIndex: 1,
        explanation: 'Todo TC é como um burro carregando carga. Essa "Carga" (Burden) é medida em VA (Volt-Ampere). Muito cabo longo ou muitos relés em série pesam as costas do TC, podendo faze-lo "desmaiar" (Saturar).',
      ),
      MultipleChoice(
        id: 'mod01_l04_q9',
        statement: 'Para transformadores de potencial (TP) especificamente, qual a maior penalidade e perigo caso a sua carga (Burden VA) permitida em catálogo sofra séria sobrecarga no painel por ignorância técnica?',
        options: ['Explosão em chamas', 'Acabar com o cobre extra das espiras elásticas da concessionária', 'Série PERDA da "Classe de Exatidão" (desvio de ângulo e amplitude massivo), sabotando proteções DIRECIONAIS e Medidores Críticos atrelados!', 'Absolutamente não afeta o sinal, apenas esquenta em 10% a malha interna do núcleo'],
        correctIndex: 2,
        explanation: 'O peso nos bornes dos TPs ferra o casamento de fases! O relé pode começar a ver correntes reversas, direções trocadas e perder precisão em cálculos essenciais de impedância por causa do erro grave de angulação!',
      ),
      TrueFalse(
        id: 'mod01_l04_q10',
        statement: 'Caso o burden nominal de um TP ou TC seja esgotado pela instalação de painéis duplos com dezenas de medidores em série na mesma roseta de furos, os equipamentos em risco perdem drasticamente a confiança nas leituras e direcionamentos ativados.',
        isTrue: true,
        explanation: 'A engenharia do Burden é fatal! Ligar muitos equipamentos na mesma "bucha do TC/TP" destrói a fidelidade da réplica - saturando por saturação de pico ou perda de ângulo, sabotando os relés num blecaute. Cada núcleo possui burden máximo inviolável.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l05',
    title: 'Impedância de Sequência Positiva, Negativa e Zero',
    subtitle: 'Diferenças entre componentes de sequência em máquinas e linhas',
    content: r'''
## Os Três Tipos de Impedância de Sequência

Cada componente de sequência enxerga uma impedância diferente nos equipamentos:

### Sequência Positiva (Z₁)
- Componente de funcionamento normal
- Para geradores: reatância sub-transitória X"d (estado inicial de falta)
- Para linhas: impedância série normal

### Sequência Negativa (Z₂)
- Componente de fase invertida (rotação oposta)
- Para geradores: Z₂ ≈ Z₁ (em máquinas modernas Z₂ ≈ X"d)
- Para linhas e transformadores: Z₂ = Z₁ (equipamentos estáticos)

### Sequência Zero (Z₀)
- Componente em fase (mesmo ângulo nas três fases)
- Depende do **aterramento** do sistema
- Para linhas: Z₀ ≈ 3 × Z₁ (devido ao retorno pela terra)
- Para transformadores: depende do grupo de ligação (Dy, Yy, etc.)
- Para geradores: Z₀ varia conforme o aterramento do neutro

> ⚠️ A sequência zero é a grandeza mais sensível ao tipo de aterramento do sistema. A compreensão correta de Z₀ é crítica para o cálculo de faltas a terra.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l05_q1',
        statement: 'Qual função magnólia clássica e complexa no padrão IEEE C37.2-2008 é representada em todo o planeta pelo número de dispositivo ANSI 21 e onde atua?',
        options: ['Relés de Sincronismo entre ilhas', 'A Nobre Proteção de DISTÂNCIA (Medição Z=V/I de impedância por patamares virtuais) - coração das Linhas de Transmissão cruciais!', 'A proteção por Descargas Atmosféricas e Raios diretos em Pararraios da ponte de barramentos', 'Sobretensão de Terra Capacitiva Residual'],
        correctIndex: 1,
        explanation: 'O reverenciado 21 é o Mago da Distância! Ele lê os TPs e TCs cruza a informação R+JX da impedância calculando geograficamente quão longe o Curto se formou para disparar Zonas!',
      ),
      MultipleChoice(
        id: 'mod01_l05_q2',
        statement: 'O famosíssimo código numérico ANSI 87 universal refere a que princípio de proteção crítica em máquinas blindadas de barramentos e transformadores?',
        options: ['Proteção Logica Distribuída Local Área', 'Diferencial Unitário Puro (Regra de Kirchhoff 1 — o que entra de corrente TEM QUE SAIR, senão atua cortando tudo ao redor instantaneamente)', 'Relés térmicos para ventoinhas triplas do trafo', 'Medidores Fasoriais de Potência Reversa com tempo inibido'],
        correctIndex: 1,
        explanation: 'As Proteções 87 (Diferencial) só olham o saldo do Caixa Eletrônico interno! Entrou 10A e saiu 9A? O relé vê fuga criminal da diferença de 1 ampere e corta toda a subestação num piscar de olhos!',
      ),
      MultipleChoice(
        id: 'mod01_l05_q3',
        statement: 'Qual Dispositivo vital mais abundante das redes possui seu coração atrelado rigorosamente ao código ANSI 50 e qual a velocidade do seu estalar?',
        options: ['Detetor de Arco com resposta em Meio Segundo', 'Relé de Mínima Tensão', 'Unidade Sensível de Sobrecorrente INSTANTÂNEA. Dispara sua faca invisível ao transpassar o Start (Pickup) sem contadores de "demora" tolerantes', 'Controles lógicos de descarte de carga por Frequência Sub-Normal (UFLS)'],
        correctIndex: 2,
        explanation: 'Quando as coisas estouram gravemente a 1 km da fonte com picos explosivos, o 50 atua de modo Fulminante, Instantâneo ao tocar o limiar com 0 (zero) segundos definidos na CPU!',
      ),
      TrueFalse(
        id: 'mod01_l05_q4',
        statement: 'A clássica função de Sobrecorrente ANSI 51 (Time Overcurrent) difere totalmente das unidades 50 (Instantâneas), operando em belas curvas Cronométricas Térmicas e tolerantes inversamente proporcionais (Mais Corrente = Menos Tempo).',
        isTrue: true,
        explanation: 'A 51 é a balança e a paciência do Relé. Tem paciência elástica baseada num gráfico de Exponencialidade Térmica (Correntes fortes mandam ele demorar menos, correntes brandas seguram ele mais por segundos).',
      ),
      MultipleChoice(
        id: 'mod01_l05_q5',
        statement: 'A qual evento físico e ativável o cão de guarda referenciado matematicamente como Função ANSI 27 está prestando imensa observação na rede?',
        options: ['Sobretensão Relâmpago', 'Mínima Voltagem/Subtensão. Atua para desarmar contatoras ou salvar ilhas ao cair o nível básico de voltagem por faltas espirais e perdas na transmissão!', 'Relé Verificador de Queda das Fases e Sequência Alternada Negativa C-B-A', 'Fluxo direcional da Potência Ativa dos geradores sincrônicos no Eixo Q'],
        correctIndex: 1,
        explanation: 'O 27 é o Guardião da Força. Se o grid perder "pressão" de V, ela desabe a tensão. Para não queimar os motores fracos com excesso de amperagem puxada em baixa tensão, ele desliga a festa (Undervoltage Trip).',
      ),
      MultipleChoice(
        id: 'mod01_l05_q6',
        statement: 'Quais são os fortes significados práticos das famosas letras designadas como sufixos "G" ou "N" adicionados e gravados muitas vzs nos IEDs, em esquemas como 50N, 51G ou 67N?',
        options: ['Gateway Station e Network Lan', 'Normalizado e Gerador', 'Terra (Ground) ou Neutro (Neutral), designando que aquelas proteções são focadas e lêem exclusivas correntes de fuga residuais via componentes Zero-Seq.', 'Not Allowed & Guarantee Tripping Code'],
        correctIndex: 2,
        explanation: 'Enquanto o 51 normal cuida das fases "A B C", o irmão leal 51 "G/N" apenas lê as sujeiras caídas ao solo e o cabo de Neutro caçado pelo desbalanço fasorial de Segurança Humana (I0 e INeutro).',
      ),
      TrueFalse(
        id: 'mod01_l05_q7',
        statement: 'O "Grau de Sensibilidade" nos velhos relés dependia de pesadas engrenagens e discos de indução movendo massa magnética. Nas modernas IEDs Digitais numéricas e microprocessadas, a sensatez atinge patamares absurdos pelo rigor das equações matemáticas limpas DSP em milésimos de Ampere calculados.',
        isTrue: true,
        explanation: 'Os Dinossauros Eletromecânicos demoravam a rodar o disco por inércia ou perdas mecânicas. Hoje, um processador Core digital analisa matematicamente a onda de 64 amostras por ciclo e envia o bip virtual 1000x mais sutil.',
      ),
      MultipleChoice(
        id: 'mod01_l05_q8',
        statement: 'Historicamente a engenharia e ciência e tecnologia associada aos relés de proteção atravessaram revoluções notáveis, podendo dividir esse universo tecnológico dos disjuntores em quatro patamares base de "Arquiteturas" em ordem de sucessão temporal:',
        options: ['Ferroviários -> Estáticos de Vidro -> Relés Internet (IoT) -> PMU e Rede Ótica Limpa S/fios', 'Relés de Bobina com Relógio Corda -> Eletromecânicos de Disco -> Painéis CLP CLP Industriais -> IED Subestações de PC', 'Eletromecânicos (Discos/Eletroímãs) -> Estáticos ou Solid State (Semicondutores TTL) -> Digitais ou Numéricos Básicos -> IED (Dispositivos Eletrônicos Inteligentes em rede Multiprocessados GOOSE e IEC-61850)', 'Valvulados Tubo -> Eletromagnéticos AC puros -> Fibra Ótica Ativa -> Cloud AWS'],
        correctIndex: 2,
        explanation: 'O avanço clássico imutável dos historiadores elétricos da proteção: Da mecânica pesada do Disco Mágico de Indução (décadas 30 a 70), aos transistores estáticos (80s), e agora aos super Pcs Digitais Multicore Modulares!',
      ),
      MultipleChoice(
        id: 'mod01_l05_q9',
        statement: 'O que a clássica "Interface Eletrônica HMI (IHM em PT-BR)" acoplada visualmente na arquitetura frontal tática de um relé (ANSI 60 etc) propicia para os operadores na frente ativa de manutenção painel?',
        options: ['Mede remotamente descargas do ar atmosférico via RFID passivo', 'Servidor VPN L2TP Local via cabo RS-232C de manobras para a nuvem', 'Human Machine Interface! A Tela, LEDS e Tecladinhos numéricos fofos para o técnico ler mensagens em claro texto da rede, extrair defeitos gravados e trocar configurações ou resets via dedo/pendrive', 'Hydraulic Motor Interrupter (Interrupção Automática Moto-Hidráulica dos religadores 79 de Pátio)'],
        correctIndex: 2,
        explanation: 'Adeus ler luzinhas e calcular flags mecânicas caídas. A Tela HMI frontal exibe: "Curto Linha Terra a 140km Fase A medindo 5200 Amperes. Pressione OK para Apagar a Tela e liberar Alarme!".',
      ),
      TrueFalse(
        id: 'mod01_l05_q10',
        statement: 'Os lendários dispositivos super rápidos conhecidos pelo acrônimo PMU (Phasor Measurement Unit - Unidade de Medição Sincrofasorial WAMS) não são Relés de barramento normais focados no disjuntor de linha, eles espalham pelo país antenas GPS e estampam o "Relógio Absoluto Timestamped" nas senóides medindo em nano-segundos balanços das linhas de um grid inteiro nacional para salvá-los.',
        isTrue: true,
        explanation: 'PMUs são satélites da Proteção: Pegam Tensão, corrente, batem continência para o Relógio Atômico do G.P.S a cada pulso, comparam todas numa Sala Gigante ONS e salvam países inteiros de blecautes oscilatóríos WAMS. O pináculo da automação smart!',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l06',
    title: 'Introdução às Componentes Simétricas',
    subtitle: 'Teorema de Fortescue e decomposição de fasores',
    content: r'''
## O Teorema de Fortescue

Em 1918, C.L. Fortescue demonstrou que **qualquer conjunto desequilibrado de três fasores** pode ser decomposto na soma de três conjuntos simétricos:

1. **Sequência Positiva (abc):** três fasores balanceados com rotação direta (normal)
2. **Sequência Negativa (acb):** três fasores balanceados com rotação inversa
3. **Sequência Zero (aaa):** três fasores iguais em magnitude e fase

### Transformação de Fortescue

$$\\begin{bmatrix} V_a \\\\ V_b \\\\ V_c \\end{bmatrix} = \\begin{bmatrix} 1 & 1 & 1 \\\\ 1 & a^2 & a \\\\ 1 & a & a^2 \\end{bmatrix} \\begin{bmatrix} V_0 \\\\ V_1 \\\\ V_2 \\end{bmatrix}$$

Onde **a = 1∠120°** é o operador de rotação.

### Por que isso importa na proteção?

A decomposição em componentes simétricas permite **analisar faltas desequilibradas** (monofásicas, bifásicas) usando **redes de sequência desacopladas**, simplificando enormemente o cálculo.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l06_q1',
        statement: 'Em um sistema trifásico equilibrado e simétrico em regime normal, qual das componentes de Fortescue está AUSENTE?',
        options: [
          'Apenas a sequência positiva',
          'Sequência negativa e sequência zero',
          'Apenas a sequência zero',
          'Todas as três sequências estão presentes sempre',
        ],
        correctIndex: 1,
        explanation: 'Em um sistema perfeitamente equilibrado (tensões iguais, defasagem de 120° entre fases), apenas a sequência positiva existe. As componentes de sequência negativa e zero são identicamente nulas — aparecem apenas com desequilíbrio ou falta.',
      ),
      MultipleChoice(
        id: 'mod01_l06_q2',
        statement: 'Se um sistema trifásico tem apenas componente de sequência zero (V₁ = V₂ = 0, V₀ ≠ 0), como são as três tensões de fase Va, Vb e Vc?',
        options: [
          'Defasadas exatamente 120° entre si',
          'Iguais em magnitude e FASE (sem defasagem entre elas)',
          'Simétricas com rotação inversa',
          'Nulas em duas fases e máximas na terceira',
        ],
        correctIndex: 1,
        explanation: 'A sequência zero representa fasores idênticos — mesma magnitude e mesmo ângulo. Va = Vb = Vc = V₀. Essa componente está presente em faltas a terra e em desequilíbrios que envolvem o neutro.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l07',
    title: 'Redes de Sequência e Conexão Entre Elas',
    subtitle: 'Monofásica (LG), bifásica (LL) e bifásica-terra (LLG)',
    content: r'''
## Redes de Sequência na Análise de Faltas

Para cada tipo de falta, as redes de sequência se conectam de maneira específica:

### Falta Trifásica (3Φ) — Rede de Sequência Positiva em Série
- Apenas Z₁ presente
- Maior corrente de falta
- $I_1 = V_F / Z_1$

### Falta Monofásica — LG (Linha-Terra)
- Redes de sequência positiva, negativa e zero em **série**
- $I_1 = I_2 = I_0 = V_F / (Z_1 + Z_2 + Z_0)$
- Corrente de falta: $I_a = 3 \\times I_1$

### Falta Bifásica — LL (Linha-Linha)
- Redes de sequência positiva e negativa em **paralelo**
- Sequência zero não participa
- $I_1 = V_F / (Z_1 + Z_2)$

### Falta Bifásica-Terra — LLG (Linha-Linha-Terra)
- Z₂ e Z₀ em paralelo, em série com Z₁
- Caso mais complexo — todas as redes participam
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l07_q1',
        statement: 'Por que uma falta LLG (bifásica com terra) é o caso mais complexo de analisar pelas componentes simétricas?',
        options: [
          'Porque gera a maior corrente de falta de todos os tipos',
          'Porque as três redes de sequência participam com uma conexão híbrida: Z₂ e Z₀ em paralelo, em série com Z₁',
          'Porque requer cálculo iterativo não linear para convergir',
          'Porque a falta LLG não pode ser modelada por componentes simétricas',
        ],
        correctIndex: 1,
        explanation: 'Na LLG, a rede de sequência positiva é conectada em série com o paralelo das redes negativa e zero — topologia mais complexa que LG (tudo em série) ou LL (positiva e negativa em paralelo sem zero).',
      ),
      TrueFalse(
        id: 'mod01_l07_q2',
        statement: 'Em um sistema com Z₀ muito maior que Z₁ (ex: sistema isolado ou com aterramento de alta impedância), a corrente de falta LG pode ser MENOR que a corrente de falta LL.',
        isTrue: true,
        explanation: 'Correto. Como I₁(LG) = Vf/(Z₁+Z₂+Z₀) e I₁(LL) = Vf/(Z₁+Z₂), um Z₀ muito alto torna o denominador da LG maior, reduzindo I₁(LG). Por isso sistemas com aterramento de alta impedância usam esse princípio para limitar correntes de falta a terra.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l08',
    title: 'Modelagem de Transformadores nas Redes de Sequência',
    subtitle: 'Influência do grupo de ligação na sequência zero',
    content: r'''
## Transformadores nas Redes de Sequência

O comportamento dos transformadores nas redes de sequência depende do **grupo de ligação** (Dy, Yy, Yd, etc.):

### Sequências Positiva e Negativa
- Transformadores sempre conduzem sequência positiva e negativa normalmente
- Impedância é a mesma: Z₁ = Z₂ = Z_transformador

### Sequência Zero — Depende do Aterramento

| Configuração | Conduz Z₀? | Observação |
|---|---|---|
| **Yn-Yn** (neutros aterrados) | ✅ Sim | Caminho para corrente zero em ambos os lados |
| **Yn-D** | ✅ apenas no lado Y | Δ bloqueia Z₀ — circula internamente |
| **Y-Y** (sem aterramento) | ❌ Não | Sem retorno para corrente de sequência zero |
| **D-D** | ❌ Não | Delta bloqueia Z₀ em ambos os lados |

> ⚠️ O transformador em **delta (Δ) bloqueia a passagem de corrente de sequência zero** para o outro lado, mas permite que circule internamente no enrolamento em triângulo.
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l08_q1',
        statement: 'Um relé de proteção de terra (51N) está instalado no neutro de um transformador Yn-D. Para que esse relé seja sensível a faltas LG no lado delta (secundário), qual condição é necessária?',
        options: [
          'O delta deve ser aterrado externamente',
          'Não é possível — o delta bloqueia Z₀ e a corrente de terra não aparece no neutro do lado Y',
          'A corrente de sequência zero circula pelo delta e retorna ao neutro do lado Y normalmente',
          'O relé 51N deve ser substituído por um relé diferencial 87T',
        ],
        correctIndex: 1,
        explanation: 'O delta bloqueia a passagem de Z₀ entre os lados. Uma falta LG no lado delta gera correntes que circulam internamente no triângulo e NÃO aparecem no neutro aterrado do lado Y — o relé 51N não vê essa falta.',
      ),
      MultipleChoice(
        id: 'mod01_l08_q2',
        statement: 'Em um transformador Yn-Yn (ambos neutros aterrados), ocorre uma falta LG no lado secundário. A corrente de sequência zero pode:',
        options: [
          'Circular apenas no secundário, sendo bloqueada na fronteira do transformador',
          'Circular em ambos os lados, pois os neutros aterrados fornecem caminho de retorno em ambas as redes de sequência zero',
          'Circular apenas no primário por ter tensão maior',
          'Ser ignorada no cálculo pois transformadores são elementos de sequência zero nula',
        ],
        correctIndex: 1,
        explanation: 'Com neutros aterrados nos dois lados, existe caminho para Z₀ em ambas as redes de sequência zero. A corrente de falta a terra "enxerga" ambos os lados, sendo esta a condição mais comum em sistemas de transmissão.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l09',
    title: 'Modelagem de Geradores e Motores',
    subtitle: 'Reatâncias sub-transitória, transitória e síncrona',
    content: r'''
## Máquinas Síncronas nas Redes de Sequência

Geradores e motores síncronos possuem **reatâncias distintas** dependendo do instante analisado após uma falta:

### Reatâncias do Eixo Direto (d-axis)

| Grandeza | Símbolo | Valor Típico | Quando Usar |
|----------|---------|--------------|-------------|
| **Sub-transitória** | X"d | 10–20% | Primeiros ciclos após a falta (análise de relés) |
| **Transitória** | X'd | 20–40% | Décimos de segundo após a falta |
| **Síncrona** | Xd | 100–200% | Regime permanente |

> ⚡ Para estudos de proteção (ajuste de relés), utiliza-se **X"d** pois representa a maior corrente de curto-circuito que o relé deve detectar.

### Sequências em Geradores

- **Z₁ do gerador:** X"d (sub-transitória no eixo d)
- **Z₂ do gerador:** ≈ X"d (geralmente próximo)
- **Z₀ do gerador:** Muito menor — depende do aterramento do neutro
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l09_q1',
        statement: 'Um gerador de 200 MVA tem X"d = 0,18 PU, X\'d = 0,28 PU e Xd = 1,60 PU. Um relé de sobrecorrente é ajustado para proteger esse gerador. Qual reatância produz o maior nível de corrente de falta que o relé deve detectar?',
        options: [
          'Xd = 1,60 PU (regime permanente — para maior estabilidade)',
          'X\'d = 0,28 PU (estado transitório — valor intermediário)',
          'X"d = 0,18 PU (sub-transitório — corrente máxima imediata)',
          'A média das três: (0,18 + 0,28 + 1,60) / 3 = 0,69 PU',
        ],
        correctIndex: 2,
        explanation: 'X"d = 0,18 PU é a menor reatância, gerando a maior corrente (I = 1/0,18 = 5,56 PU). O relé DEVE ser sensível a essa corrente máxima imediatamente após a falta. Usar Xd resultaria em I = 1/1,60 = 0,625 PU — muito menor, podendo o relé não "ver" a falta.',
      ),
      TrueFalse(
        id: 'mod01_l09_q2',
        statement: 'Um motor de indução contribui para a corrente de curto-circuito imediatamente após uma falta, pois age temporariamente como um gerador durante o regime sub-transitório.',
        isTrue: true,
        explanation: 'Correto. Os motores de indução em operação têm energia armazenada no campo magnético rotórico. Nos primeiros ciclos após a falta, eles injetam corrente no sistema (contribuição de curto), que deve ser considerada nos cálculos de proteção.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_l10',
    title: 'Cálculo Completo de Falta Monofásica (LG)',
    subtitle: 'Aplicação prática das componentes simétricas em LG Fault',
    content: r'''
## Estudo de Caso: Falta Monofásica à Terra

A falta LG (Linha-Terra) é a mais comum em sistemas de potência (~70–80% de todas as faltas).

### Procedimento Completo

**Dados do sistema (em PU, Sbase = 100 MVA):**
- Gerador: Z₁ = Z₂ = j0,20 PU; Z₀ = j0,05 PU
- Transformador: Z₁ = Z₂ = j0,10 PU; Z₀ = j0,10 PU
- Linha: Z₁ = Z₂ = j0,15 PU; Z₀ = j0,50 PU
- Tensão pré-falta: 1,0 PU

**Passo 1:** Calcular impedância total de cada sequência
- Z₁_total = j(0,20 + 0,10 + 0,15) = j0,45 PU
- Z₂_total = j(0,20 + 0,10 + 0,15) = j0,45 PU
- Z₀_total = j(0,05 + 0,10 + 0,50) = j0,65 PU

**Passo 2:** Calcular corrente de sequência positiva
$$I_1 = I_2 = I_0 = \\frac{V_F}{Z_1 + Z_2 + Z_0} = \\frac{1{,}0}{j(0{,}45 + 0{,}45 + 0{,}65)} = \\frac{1{,}0}{j1{,}55} = -j0{,}645 \\ PU$$

**Passo 3:** Corrente de falta total
$$I_{falta} = 3 \\times I_1 = 3 \\times 0{,}645 = 1{,}935 \\ PU$$
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l10_q1',
        statement: 'No estudo de caso da Lição 10 (Z₁=Z₂=j0,45 PU, Z₀=j0,65 PU), se o sistema de aterramento for modificado eliminando o neutro aterrado (Z₀→∞), o que acontece com a corrente de falta LG?',
        options: [
          'A corrente LG dobra pois a falta fica mais grave',
          'A corrente LG vai para zero — sem caminho de retorno para sequência zero, não há corrente de falta a terra',
          'A corrente LG se mantém igual, pois Z₁ e Z₂ dominam',
          'A falta LG se converte automaticamente em falta LL',
        ],
        correctIndex: 1,
        explanation: 'Com Z₀→∞, o denominador Z₁+Z₂+Z₀→∞, fazendo I₁→0 e portanto I_falta=3×I₁→0. Isso é exatamente o princípio dos sistemas com neutro isolado (IT): as correntes de falta a terra são naturalmente limitadas.',
      ),
      MultipleChoice(
        id: 'mod01_l10_q2',
        statement: 'Comparando os resultados típicos: falta LG (I = 1,94 PU) vs. falta 3Φ (I = 2,22 PU) no mesmo sistema. Qual conclusão prática isso gera para o ajuste do relé de sobrecorrente de fase?',
        options: [
          'O relé deve ser ajustado pela corrente de falta LG, pois é mais comum',
          'O relé de fase deve ser ajustado pela falta 3Φ (maior corrente); o relé de terra protege as faltas LG',
          'Como são próximos, qualquer valor entre 1,94 e 2,22 PU serve como ajuste',
          'O relé de fase deve ignorar faltas LG — são tratadas apenas pelo disjuntor de neutro',
        ],
        correctIndex: 1,
        explanation: 'Relés de fase (50/51) são ajustados para detectar faltas de fase (3Φ, LL). Relés de terra (50N/51N/67N) são ajustados especificamente para faltas LG e LLG, frequentemente com sensibilidade maior. Isso permite discriminação entre tipos de falta.',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════
  //  BLOCO B: APLICAÇÕES E ESTUDOS AVANÇADOS (Lições 11–20)
  // ══════════════════════════════════════════════════════════════

  Lesson(
    id: 'mod01_l11',
    title: 'Interpretação de Resultados PU em Relés',
    subtitle: 'Como relés digitais trabalham com grandezas PU',
    content: 'Relés digitais convertem sinais de TCs e TPs para PU internamente. O ajuste de pickup, por exemplo, é feito em múltiplos da corrente nominal (In), que corresponde a 1,0 PU na escala do relé.',
    questions: [
      MultipleChoice(
        id: 'mod01_l11_q1',
        statement: 'Um relé de sobrecorrente tem pickup ajustado em 1,5×In, onde In = 5 A (secundário do TC 600/5). Qual corrente primária na linha faz o relé atuar?',
        options: [
          '7,5 A primários',
          '450 A primários',
          '900 A primários',
          '180 A primários',
        ],
        correctIndex: 1,
        explanation: 'Pickup secundário = 1,5 × 5 A = 7,5 A. Corrente primária = 7,5 × (600/5) = 7,5 × 120 = 900 A. Espera! O cálculo correto: corrente primária de trip = 7,5 A × (600/5) = 900 A. Revisão: a relação TC = 600/5 = 120:1. Pickup = 1,5In = 7,5 A (sec.) = 7,5 × 120 = 900 A. Aguarda: a resposta correta é 900 A — opção B. Nota: 450 A corresponderia a 1,5 A no secundário, não 7,5 A.',
      ),
      TrueFalse(
        id: 'mod01_l11_q2',
        statement: 'Em relés digitais modernos, o ajuste de impedância para proteção de distância é geralmente inserido em ohms primários (ou secundários), não em PU.',
        isTrue: true,
        explanation: 'Correto. Apesar de a teoria usar PU, a interface do engenheiro com relés de distância modernos usa ohms (primários ou referidos ao secundário do TP/TC). O relé converte internamente. É fundamental entender a conversão ohms ↔ PU para validar os ajustes.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l12',
    title: 'Falta Bifásica (LL) — Análise Completa',
    subtitle: 'Redes de sequência positiva e negativa em paralelo',
    content: 'A falta LL conecta as redes de sequência positiva e negativa em paralelo (sem sequência zero). Resulta em I₁ = Vf/(Z₁+Z₂) e corrente de falta = √3 × I₁ para faltas metálicas com Z₁ = Z₂.',
    questions: [
      MultipleChoice(
        id: 'mod01_l12_q1',
        statement: 'Para Z₁ = Z₂ = j0,25 PU, qual a relação entre a corrente de falta LL e a corrente de falta 3Φ no mesmo sistema?',
        options: [
          'I_LL = I_3Φ (iguais)',
          'I_LL = 0,866 × I_3Φ (√3/2 da falta trifásica)',
          'I_LL = 1,5 × I_3Φ (maior por envolver duas fases)',
          'I_LL depende do ângulo de incidência da falta',
        ],
        correctIndex: 1,
        explanation: 'I_3Φ = 1/Z₁ = 1/0,25 = 4 PU. I_LL = Vf/(Z₁+Z₂) = 1/0,50 = 2 PU de sequência positiva. Corrente de fase = √3 × 2 = 3,46 PU. Relação: 3,46/4 = 0,866 = √3/2. Essa relação é verdade sempre que Z₁=Z₂.',
      ),
      TrueFalse(
        id: 'mod01_l12_q2',
        statement: 'Na falta LL (bifásica sem terra), as correntes de falta nas duas fases envolvidas são iguais em módulo mas opostas em fase.',
        isTrue: true,
        explanation: 'Correto. Na falta bifásica, Ib = -Ic e Ia = 0. As duas correntes são iguais em magnitude e defasadas de 180°. Isso é verificado quando se observa que apenas as sequências positiva e negativa participam.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l13',
    title: 'Falta Bifásica-Terra (LLG) — Análise',
    subtitle: 'Conexão híbrida com as três redes de sequência',
    content: 'Na falta LLG, a rede de sequência positiva conecta em série com o paralelo de Z₂ e Z₀. É o tipo de falta com maior variação de corrente dependendo de Z₀, podendo superar a falta 3Φ em sistemas com Z₀ baixo.',
    questions: [
      MultipleChoice(
        id: 'mod01_l13_q1',
        statement: 'Em qual situação a corrente de falta LLG pode ser MAIOR que a corrente de falta trifásica (3Φ)?',
        options: [
          'Sempre que Z₂ > Z₁',
          'Quando Z₀ é muito pequeno (sistema solidamente aterrado com neutro de baixa impedância)',
          'Nunca — a falta 3Φ sempre gera a maior corrente',
          'Quando a falta ocorre próxima ao gerador',
        ],
        correctIndex: 1,
        explanation: 'Com Z₀ muito pequeno, o paralelo (Z₂//Z₀) se torna muito pequeno, reduzindo a impedência equivalente total. Isso pode fazer I₁(LLG) > I₁(3Φ) = 1/Z₁. O sistema solidamente aterrado tipicamente apresenta correntes de falta LLG e LG mais elevadas.',
      ),
      FillInTheBlanks(
        id: 'mod01_l13_q2',
        statement: 'Complete a topologia de conexão para falta LLG:',
        textWithBlanks: 'Na falta LLG, as redes de sequência ____ e ____ ficam em paralelo, e esse conjunto em série com a rede de sequência ____.',
        blanks: [
          Blank(index: 0, answer: 'negativa'),
          Blank(index: 1, answer: 'zero'),
          Blank(index: 2, answer: 'positiva'),
        ],
        explanation: 'Na LLG: Z_eq = Z₁ + (Z₂ // Z₀). As redes negativa e zero em paralelo formam a impedência de retaguarda, em série com a positiva.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l14',
    title: 'Corrente Residual e Proteção de Terra',
    subtitle: 'Detecção de faltas terra via sequência zero',
    content: 'A corrente residual (3I₀) é a soma das três correntes de fase: Ir = Ia + Ib + Ic = 3I₀. Em regime normal (sistema equilibrado), Ir = 0. Qualquer corrente residual indica desequilíbrio ou falta a terra.',
    questions: [
      TrueFalse(
        id: 'mod01_l14_q1',
        statement: 'A corrente residual medida no neutro do transformador (3I₀) é zero em condições normais de operação equilibrada, e seu aparecimento é indicativo de falta ou desequilíbrio.',
        isTrue: true,
        explanation: 'Em regime normal equilibrado, Ia+Ib+Ic=0 (soma fasorial). A corrente de neutro 3I₀ = Ia+Ib+Ic só existe quando há desequilíbrio — tipicamente em faltas a terra ou desequilíbrios de carga.',
      ),
      MultipleChoice(
        id: 'mod01_l14_q2',
        statement: 'Para detectar faltas com alta resistência de falta a terra (onde a corrente é pequena), qual estratégia de proteção é mais eficaz?',
        options: [
          'Relé de sobrecorrente de fase (51) com pickup alto',
          'Relé de terra com pickup baixo (alta sensibilidade) — função 51N ou 67N',
          'Proteção diferencial de barra (87B)',
          'Relé de frequência (81)',
        ],
        correctIndex: 1,
        explanation: 'O relé de terra (51N) pode ter pickup muito abaixo do nominal de carga (ex: 5-10% de In), pois durante operação normal 3I₀ = 0. Isso permite detectar faltas resistivas de terra que seriam invisíveis para o relé de fase.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l15',
    title: 'Redução de Redes — Equivalente de Thevenin',
    subtitle: 'Simplificação de redes complexas para análise de faltas',
    content: 'O Teorema de Thevenin permite substituir qualquer rede linear por uma fonte de tensão em série com uma impedância. Para estudos de curto-circuito em PU, calcula-se Z_th (com fontes zeradas) e V_th = 1∠0° PU (pré-falta).',
    questions: [
      MultipleChoice(
        id: 'mod01_l15_q1',
        statement: 'Para calcular a corrente de falta em uma barra de um sistema de potência com múltiplas fontes, o método correto é:',
        options: [
          'Somar todas as correntes de cada fonte individualmente',
          'Calcular o equivalente de Thevenin na barra de falta (Z_th e V_th) e usar I_falta = V_th/Z_th',
          'Usar a corrente máxima de cada gerador em paralelo',
          'Aplicar a regra do divisor de corrente entre todas as fontes',
        ],
        correctIndex: 1,
        explanation: 'O equivalente de Thevenin é o método padrão: (1) zerar todas as fontes de tensão interna, (2) calcular Z_th visto da barra de falta, (3) usar V_th = 1,0 PU (pré-falta). O resultado é independente de como as fontes estão distribuídas.',
      ),
      TrueFalse(
        id: 'mod01_l15_q2',
        statement: 'Em estudos de curto-circuito, a tensão pré-falta no sistema é geralmente assumida como 1,0∠0° PU para simplificar os cálculos.',
        isTrue: true,
        explanation: 'Correto. Essa é uma hipótese simplificadora padrão (“pre-fault voltage = 1 PU”). Para estudos mais precisos, pode-se usar a tensão real pré-falta obtida de um estudo de fluxo de carga, mas 1,0 PU é aceita na maioria das aplicações de proteção.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l16',
    title: 'Efeito da Resistência de Falta nos Cálculos',
    subtitle: 'Faltas resistivas e limitação dos métodos clássicos',
    content: 'A resistência de arco elétrico e do solo add-se à impedância da falta. Em componentes simétricas, Rf aparece em série nas redes de sequência, reduzindo a corrente de falta e dificultando a detecção.',
    questions: [
      TrueFalse(
        id: 'mod01_l16_q1',
        statement: 'A presença de resistência de arco em uma falta sempre reduz a corrente de falta e pode dificultar a detecção pelo relé de proteção.',
        isTrue: true,
        explanation: 'Correto. Com resistência de falta Rf, I_falta = Vf/(Z_th + Rf). O aumento do denominador reduz a corrente. Para relés de sobrecorrente, a falta pode ficar abaixo do pickup. Para relés de distância, a impedência aparente sai do alvo, dificultando a detecção.',
      ),
      MultipleChoice(
        id: 'mod01_l16_q2',
        statement: 'A resistência de arco elétrico em uma falta de linha-terra depende principalmente de:',
        options: [
          'Apenas da tensão do sistema (quanto mais alta, maior o arco)',
          'Da corrente de arco, comprimento do arco e condições ambientais (vento, umidade)',
          'Exclusivamente da impedância da fonte Thevenin',
          'Do tipo de relé instalado na subestacão',
        ],
        correctIndex: 1,
        explanation: 'A resistência de arco é determinada pela fórmula de Warrington (R_arco ≈ 28.710/I^1.4 × L, onde L é o comprimento do arco em metros). Vento pode “alongar” o arco e aumentar a resistência. Sua variação dinâmica é um desafio para relés de distância.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l17',
    title: 'Sistemas de Aterramento e Sequência Zero',
    subtitle: 'Impacto do aterramento nas correntes de falta',
    content: 'O método de aterramento define Z₀ efetivo e portanto a magnitude das correntes de falta a terra. Sistemas solidamente aterrados, com resistência, resonância (Petersen) e isolados têm comportamentos radicalmente diferentes.',
    questions: [
      MultipleChoice(
        id: 'mod01_l17_q1',
        statement: 'Em um sistema com aterramento por bobina de Petersen (aterramento ressonante), o que acontece com a corrente de falta LG?',
        options: [
          'A corrente de falta é máxima, pois a bobina amplifica a corrente',
          'A corrente de falta capacitiva é compensada pela corrente indutiva da bobina, resultando em corrente de falta muito pequena',
          'A corrente de falta LG se torna igual à corrente de falta 3Φ',
          'O sistema não permite a passagem de qualquer corrente de falta',
        ],
        correctIndex: 1,
        explanation: 'A bobina de Petersen (ou bobina de extinguição) é sintonizada para ressonar com a capacitância de sequência zero do sistema. Em ressonância, a corrente indutiva cancela a capacitiva, resultando em uma corrente de falta praticamente nula — permitindo até auto-extinguição do arco.',
      ),
      TrueFalse(
        id: 'mod01_l17_q2',
        statement: 'Sistemas com neutro aterrado solidamente têm correntes de falta a terra tipicamente maiores que sistemas com neutro isolado, justificando o uso de relés de terra com maior capacidade de interrupção nesses sistemas.',
        isTrue: true,
        explanation: 'Correto. Com neutro sólido (Z₀ ≈ 0), I_LG = 3Vf/(Z₁+Z₂) — correntes elevadas. Com neutro isolado (Z₀ → ∞), I_LG → 0. Disjuntores e relés de terra devem ser dimensionados para a corren corrente do pior caso do seu sistema de aterramento.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l18',
    title: 'Fluxo de Carga em Sistema PU',
    subtitle: 'Newton-Raphson e Gauss-Seidel em PU',
    content: 'O fluxo de carga em PU modela a rede com barras de geração (PV), carga (PQ) e referência (θ=0). Os resultados (V e θ em PU e radianos) alimentam os estudos de estabilidade e ajuste de tensão.',
    questions: [
      MultipleChoice(
        id: 'mod01_l18_q1',
        statement: 'Em um estudo de fluxo de carga, a barra de referência (barra θ) tem qual função específica?',
        options: [
          'Define a maior carga do sistema',
          'Fornece a referência angular (θ=0) e equilibra a potência ativa do sistema (barra slack)',
          'Representa o neutro de aterramento do sistema',
          'Mantém a tensão constante em todos os nós adjacentes',
        ],
        correctIndex: 1,
        explanation: 'A barra slack (referência ou swing) tem θ=0 e |V| fixos, e absorve o desequilíbrio de potência do sistema (perdas não previstas). Tipicamente é a barra de um grande gerador de referência.',
      ),
      TrueFalse(
        id: 'mod01_l18_q2',
        statement: 'Os resultados de um fluxo de carga (tensões e ângulos em PU) são utilizados como condição inicial para estudos de estabilidade transitória e como condição pré-falta em cálculos de curto-circuito.',
        isTrue: true,
        explanation: 'Correto. O fluxo de carga define o estado operacional do sistema antes de qualquer evento. Seus resultados alimentam diretamente: (1) estudos de curto-circuito como tensão pré-falta, (2) estudos de estabilidade como condição inicial dos ângulos de rotor.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l19',
    title: 'Modelagem de Cargas e Linhas em PU',
    subtitle: 'Representação de cargas constantes, corrente e impedância',
    content: 'O modelo ZIP (Z = impedância, I = corrente, P = potência constante) representa a dependência da carga com a tensão. Linhas de transmissão são modeladas como parâmetros distribuídos (π nominal para linhas médias).',
    questions: [
      MultipleChoice(
        id: 'mod01_l19_q1',
        statement: 'Uma carga modelada como impedância constante (Z) em PU. Se a tensão do barramento cair para 0,9 PU (de 1,0 PU), a potência absorvida por essa carga será:',
        options: [
          '90% da potência nominal (proporcional à tensão)',
          '81% da potência nominal (proporcional ao quadrado da tensão)',
          '100% — carga de impedância constante não varia com a tensão',
          '111% — a carga compensa a queda de tensão aumentando a corrente',
        ],
        correctIndex: 1,
        explanation: 'P = V²/Z. Com Z constante, P ∝ V². Se V cai para 0,9 PU, P_novo = (0,9)² × P_nom = 0,81 × P_nom. Isso é diferente de carga de potência constante (P), onde a corrente aumenta para compensar a queda de V.',
      ),
      TrueFalse(
        id: 'mod01_l19_q2',
        statement: 'Para linhas curtas de distribuição (abaixo de 80 km), o modelo pi nominal é geralmente substituído pelo modelo série simples (apenas R+jX), pois a capacitância shunt é desprezível.',
        isTrue: true,
        explanation: 'Correto. A capacitância shunt de linhas curtas gera corrente reativa insignificante. O modelo série (R+jX em série) é suficiente. Para linhas longas (>80 km), o modelo pi nominal ou parâmetros distribuídos se torna necessário.',
      ),
    ],
  ),
  Lesson(
    id: 'mod01_l20',
    title: 'Revisão Geral — Módulo 01',
    subtitle: 'Consolidação: PU, Componentes Simétricas e Aplicações',
    content: r'''
## Revisão: Módulo 01 — Pontos Essenciais

### Sistema Por Unidade (PU)
- X_PU = X_real / X_base
- Uma Sbase para todo o sistema; Vbase por região (separada por transformadores)
- Conversão entre bases: Z_novo = Z_antigo × (Snovo/Santigo) × (Vantigo/Vnovo)²

### Componentes Simétricas
- Fortescue (1918): qualquer sistema desequilibrado = soma de sequências +, -, 0
- Operador a = 1∠120°
- Faltas: LG → série; LL → paralelo (+/-); LLG → complexo; 3Φ → apenas +

### Tipos de Impedância de Sequência
- Z₁ = Z₂ (elementos estáticos)
- Z₀ depende do aterramento e configuração dos transformadores
- Delta: bloqueia Z₀. Yn aterrado: permite Z₀.

### Para Estudos de Proteção
- Use X"d (sub-transitória) — máxima corrente de falta
- Falta LG é a mais comum (70-80% dos casos)
    ''',
    questions: [
      MultipleChoice(
        id: 'mod01_l20_q1',
        statement: 'Qual tipo de falta representa a maior percentagem de ocorrências em sistemas de potência?',
        options: ['Trifásica (3Φ)', 'Bifásica-terra (LLG)', 'Bifásica (LL)', 'Monofásica-terra (LG)'],
        correctIndex: 3,
        explanation: 'A falta LG (monofásica à terra) é a mais frequente, representando cerca de 70-80% de todas as ocorrências. Faltas trifásicas são as mais raras.',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════
  //  AVALIAÇÕES (4)
  // ══════════════════════════════════════════════════════════════

  Lesson(
    id: 'mod01_eval1',
    title: 'Avaliação 1 · Sistema Por Unidade — Fundamentos',
    subtitle: 'Conceitos de base, normalização e conversão',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod01_eval1_q1',
        statement: 'Qual é a principal vantagem do Sistema PU em sistemas com múltiplos transformadores?',
        options: [
          'Aumenta a precisão das medições de campo',
          'Elimina a necessidade de considerar relações de espiras nos cálculos de impedância',
          'Converte as grandezas para valores percentuais de 0 a 100',
          'Padroniza a frequência do sistema para 60 Hz',
        ],
        correctIndex: 1,
        explanation: 'Ao escolher bases de tensão coerentes em cada região, as relações de espiras dos transformadores são incorporadas nas bases, desaparecendo dos cálculos de impedância.',
      ),
      MultipleChoice(
        id: 'mod01_eval1_q2',
        statement: 'Um motor de 10 MVA tem reatância de 0,15 PU na sua base. Para convertê-la à base do sistema de 100 MVA (mesma tensão base), o valor será:',
        options: ['0,015 PU', '0,15 PU', '1,50 PU', '0,50 PU'],
        correctIndex: 2,
        explanation: 'Z_novo = 0,15 × (100/10) × 1² = 1,50 PU. O aumento da base de potência eleva o valor PU da impedância.',
      ),
      TrueFalse(
        id: 'mod01_eval1_q3',
        statement: 'Em um sistema de potência com múltiplos níveis de tensão, é necessário definir uma base de tensão diferente para cada região separada por transformadores.',
        isTrue: true,
        explanation: 'Correto. A Vbase muda a cada transformador de acordo com a relação de transformação, enquanto Sbase permanece constante em todo o sistema.',
      ),
      FillInTheBlanks(
        id: 'mod01_eval1_q4',
        statement: 'Complete a fórmula da impedância base:',
        textWithBlanks: 'Z_base = ____² / ____',
        blanks: [
          Blank(index: 0, answer: 'V_base'),
          Blank(index: 1, answer: 'S_base'),
        ],
        explanation: 'Z_base = V_base² / S_base. Com V_base em kV e S_base em MVA, Z_base resulta em ohms.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_eval2',
    title: 'Avaliação 2 · Componentes Simétricas',
    subtitle: 'Fortescue, redes de sequência e tipos de falta',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod01_eval2_q1',
        statement: 'O operador "a" na transformação de Fortescue representa:',
        options: ['Uma rotação de 90°', 'Uma rotação de 120°', 'Uma rotação de 180°', 'Uma rotação de 240°'],
        correctIndex: 1,
        explanation: 'O operador a = 1∠120° representa uma rotação de 120° no plano fasorial complexo.',
      ),
      MultipleChoice(
        id: 'mod01_eval2_q2',
        statement: 'Em uma falta bifásica (LL — sem envolvimento de terra), qual rede de sequência NÃO participa?',
        options: ['Positiva', 'Negativa', 'Zero', 'Todas participam'],
        correctIndex: 2,
        explanation: 'Na falta LL sem terra, não há caminho de retorno para corrente de sequência zero. Apenas as redes positiva e negativa participam (em paralelo).',
      ),
      TrueFalse(
        id: 'mod01_eval2_q3',
        statement: 'Em uma falta LG, a corrente total de falta na fase é igual a 3 vezes a componente de sequência positiva (Ia = 3 × I₁).',
        isTrue: true,
        explanation: 'Correto. Como I₁ = I₂ = I₀ na falta LG, a corrente de falta total é Ia = I₁ + I₂ + I₀ = 3 × I₁.',
      ),
      MultipleChoice(
        id: 'mod01_eval2_q4',
        statement: 'Um transformador com ligação D-Yn (delta no primário, estrela aterrada no secundário) em relação à sequência zero:',
        options: [
          'Conduz Z₀ em ambos os lados normalmente',
          'Bloqueia Z₀ em ambos os lados',
          'Conduz Z₀ pelo lado Yn; delta bloqueia passagem para o lado D',
          'Conduz Z₀ pelo lado D; estrela bloqueia do lado Yn',
        ],
        correctIndex: 2,
        explanation: 'O neutro aterrado no lado Y cria caminho para corrente de sequência zero neste lado. O delta do outro lado bloqueia a passagem — a corrente circula internamente no triângulo.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_eval3',
    title: 'Avaliação 3 · Cálculo de Faltas',
    subtitle: 'Aplicação prática de PU em estudos de curto-circuito',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod01_eval3_q1',
        statement: 'Para ajuste de relés de proteção, qual reatância de gerador representa o pior caso de corrente de falta?',
        options: ['Síncrona (Xd)', 'Transitória (X\'d)', 'Sub-transitória (X"d)', 'De eixo em quadratura (Xq)'],
        correctIndex: 2,
        explanation: 'X"d (sub-transitória) é a menor reatância, resultando na maior corrente de falta. É o cenário crítico que os relés devem detectar.',
      ),
      TrueFalse(
        id: 'mod01_eval3_q2',
        statement: 'Para elementos estáticos (linhas e transformadores), Z₁ = Z₂ (sequência positiva = negativa).',
        isTrue: true,
        explanation: 'Correto. A diferença entre Z₁ e Z₂ só existe em máquinas rotativas. Para elementos estáticos, não há assimetria e Z₁ = Z₂.',
      ),
      MultipleChoice(
        id: 'mod01_eval3_q3',
        statement: 'A corrente de curto-circuito trifásico em PU com Vf = 1,0 PU e Z₁ = j0,20 PU é:',
        options: ['0,20 PU', '1,0 PU', '5,0 PU', '20,0 PU'],
        correctIndex: 2,
        explanation: 'I_cc = Vf / Z₁ = 1,0 / 0,20 = 5,0 PU. Em amperes reais, multiplica-se pela corrente base da região.',
      ),
    ],
  ),

  Lesson(
    id: 'mod01_eval4',
    title: 'Avaliação Final · Módulo 01',
    subtitle: 'Avaliação integrada de todos os tópicos',
    type: LessonType.evaluation,
    content: '',
    questions: [
      MultipleChoice(
        id: 'mod01_eval4_q1',
        statement: 'Por que a impedância de sequência zero de uma linha de transmissão é tipicamente ~3 vezes maior que Z₁?',
        options: [
          'Pela frequência tripla da sequência zero',
          'Pelo retorno da corrente de sequência zero pela terra (maior impedância de caminho)',
          'Pela capacitância das três fases em sequência zero',
          'Pela convenção da norma IEEE 80',
        ],
        correctIndex: 1,
        explanation: 'Na sequência zero, as três fases têm correntes em fase, cujo retorno ocorre pela terra/cabo de guarda. A impedância desse caminho é muito maior que dos condutores, elevando Z₀.',
      ),
      TrueFalse(
        id: 'mod01_eval4_q2',
        statement: 'A falta trifásica balanceada é the worst case para corrente de falta em sistemas com geração forte (baixa impedância de sequência positiva).',
        isTrue: true,
        explanation: 'Correto. Na falta 3Φ, apenas Z₁ limita a corrente. Em sistemas com Z₀ > Z₁ (comum em sistemas de distribuição), a falta LG pode ter corrente maior, mas a regra geral de dimensionamento usa 3Φ.',
      ),
      MultipleChoice(
        id: 'mod01_eval4_q3',
        statement: 'Em um sistema com Sbase = 100 MVA e Vbase = 69 kV, a impedância base é aproximadamente:',
        options: ['0,69 Ω', '47,6 Ω', '69 Ω', '4760 Ω'],
        correctIndex: 1,
        explanation: 'Z_base = V_base² / S_base = 69² / 100 = 4761 / 100 = 47,6 Ω (com V em kV e S em MVA).',
      ),
      FillInTheBlanks(
        id: 'mod01_eval4_q4',
        statement: 'Fortescue demonstrou que qualquer sistema trifásico desequilibrado pode ser decomposto em três componentes:',
        textWithBlanks: 'Sequência ____, sequência ____ e sequência ____.',
        blanks: [
          Blank(index: 0, answer: 'positiva'),
          Blank(index: 1, answer: 'negativa'),
          Blank(index: 2, answer: 'zero'),
        ],
        explanation: 'As três componentes simétricas de Fortescue são: sequência positiva (rotação normal), sequência negativa (rotação inversa) e sequência zero (fasores em fase).',
      ),
    ],
  ),
];
