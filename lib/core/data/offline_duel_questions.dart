import 'package:spark_app/models/match_models.dart';

/// Banco de perguntas LOCAL para o treino offline do Duelo de Faíscas.
///
/// Quando não há internet, não é possível buscar as questões das trilhas no
/// Firestore — então usamos este banco embutido. O treino offline serve só
/// para praticar e NÃO afeta o ranking/ELO.
///
/// Tema: segurança elétrica / NR-10 / NR-35 (mesmo domínio do app).
const List<DuelQuestion> kOfflineDuelQuestions = [
  DuelQuestion(
    id: 'off_01',
    statement: 'A partir de qual tensão a NR-10 já se aplica a instalações elétricas?',
    options: ['12 V', '24 V', 'Qualquer tensão', '50 V'],
    correctIndex: 2,
  ),
  DuelQuestion(
    id: 'off_02',
    statement: 'O que significa a sigla EPI?',
    options: [
      'Equipamento de Proteção Individual',
      'Estrutura de Proteção Interna',
      'Equipamento Padrão Industrial',
      'Elemento de Prevenção Integrada',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_03',
    statement: 'Qual NR trata especificamente de trabalho em altura?',
    options: ['NR-10', 'NR-12', 'NR-33', 'NR-35'],
    correctIndex: 3,
  ),
  DuelQuestion(
    id: 'off_04',
    statement: 'Qual é o primeiro passo ao encontrar um cabo energizado desencapado?',
    options: [
      'Isolar a área e sinalizar o risco',
      'Tocar para verificar a tensão',
      'Continuar o trabalho com cuidado',
      'Cobrir com pano seco',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_05',
    statement: 'Na sequência de desenergização, o que deve ser feito logo após o seccionamento?',
    options: [
      'Impedimento de reenergização',
      'Liberar para o serviço',
      'Aterramento temporário',
      'Constatação de ausência de tensão',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_06',
    statement: 'O choque elétrico por contato com duas fases é classificado como contato:',
    options: ['Direto', 'Indireto', 'Por arco', 'Capacitivo'],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_07',
    statement: 'Qual a função principal do condutor de aterramento (terra)?',
    options: [
      'Escoar correntes de fuga para a terra com segurança',
      'Aumentar a tensão do circuito',
      'Reduzir o consumo de energia',
      'Substituir o disjuntor',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_08',
    statement: 'O dispositivo DR (Diferencial Residual) protege principalmente contra:',
    options: [
      'Choque elétrico por corrente de fuga',
      'Sobrecarga de motores',
      'Queda de tensão',
      'Curto-circuito apenas',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_09',
    statement: 'Validade padrão do treinamento de reciclagem da NR-10 (básico):',
    options: ['A cada 6 meses', 'A cada 2 anos', 'A cada 5 anos', 'Não há reciclagem'],
    correctIndex: 1,
  ),
  DuelQuestion(
    id: 'off_10',
    statement: 'A "zona de risco" em instalações elétricas é a região onde:',
    options: [
      'Só profissionais autorizados entram com medidas de controle',
      'Qualquer pessoa pode circular',
      'É proibido qualquer trabalho para sempre',
      'Não há risco elétrico',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_11',
    statement: 'Qual EPI é indispensável para proteção contra arco elétrico?',
    options: [
      'Vestimenta com proteção contra arco (FR)',
      'Camiseta de algodão comum',
      'Colete refletivo simples',
      'Avental plástico',
    ],
    correctIndex: 0,
  ),
  DuelQuestion(
    id: 'off_12',
    statement: 'Antes de iniciar serviço em circuito, a ausência de tensão deve ser:',
    options: [
      'Constatada com detector/voltímetro apropriado',
      'Presumida se a chave estiver desligada',
      'Confirmada apenas verbalmente',
      'Ignorada se houver pressa',
    ],
    correctIndex: 0,
  ),
];
