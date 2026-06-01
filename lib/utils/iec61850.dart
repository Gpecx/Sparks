// Ferramentas de campo para IEC 61850 — GOOSE e Sampled Values (SV).
//
// Triagem de comissionamento (não substitui sniffer/analisador). Cobre:
//   • GOOSE: sequência de retransmissão (T0 estável, T1 após evento dobrando
//     até voltar a T0) e verificação do requisito de tempo por tipo de mensagem.
//   • SV: amostras/ciclo → amostras/s → pacotes/s e banda estimada.
//   • Endereçamento: faixa de MAC multicast (GOOSE/SV), APPID, VLAN-ID/prioridade.

// ── GOOSE: sequência de retransmissão ────────────────────────────
// Após um evento, o IED retransmite rápido (T1) e vai dobrando o intervalo
// até estabilizar no tempo de "keep-alive" T0. Gera a sequência de intervalos.
List<int> gooseRetransmissionSequence({
  required int t1Ms, // 1º intervalo após o evento
  required int t0Ms, // intervalo estável (keep-alive)
  double multiplier = 2.0,
}) {
  final seq = <int>[];
  if (t1Ms <= 0 || t0Ms <= 0) return seq;
  var t = t1Ms;
  // limita a 12 passos por segurança (a sequência sempre converge a T0)
  for (var i = 0; i < 12; i++) {
    if (t >= t0Ms) {
      seq.add(t0Ms);
      break;
    }
    seq.add(t);
    t = (t * multiplier).round();
  }
  if (seq.isEmpty || seq.last != t0Ms) seq.add(t0Ms);
  return seq;
}

// Requisito de tempo de transferência por tipo/classe de mensagem (IEC 61850-5).
// Retorna o limite recomendado em ms (transfer time total, incl. processamento).
class GooseMessageClass {
  final String name;
  final double maxTransferMs;
  const GooseMessageClass(this.name, this.maxTransferMs);
}

const gooseMessageClasses = <GooseMessageClass>[
  GooseMessageClass('Tipo 1A — Trip (P1)', 3),
  GooseMessageClass('Tipo 1A — Trip (P2/P3)', 3),
  GooseMessageClass('Tipo 1B — Outros rápidos (P1)', 10),
  GooseMessageClass('Tipo 1B — Outros rápidos (P2/P3)', 20),
  GooseMessageClass('Tipo 4 — Bloqueio/intertravamento', 100),
];

// Verdadeiro se o tempo medido/estimado atende ao requisito da classe.
bool gooseTimeOk({required double measuredMs, required double maxTransferMs}) {
  return measuredMs <= maxTransferMs;
}

// ── SV: taxa de amostragem → pacotes/s e banda ───────────────────
class SvRate {
  final int samplesPerSecond; // amostras/s
  final int packetsPerSecond; // pacotes/s (no 9-2LE, 1 ASDU/frame)
  final double estimatedMbps; // banda aproximada (Mbit/s)

  const SvRate({
    required this.samplesPerSecond,
    required this.packetsPerSecond,
    required this.estimatedMbps,
  });
}

// samplesPerCycle: 80 (proteção, 9-2LE) ou 256 (medição/qualidade).
// frequency: 50 ou 60 Hz. asduPerFrame: amostras agregadas por frame (9-2LE=1).
// frameBytes: tamanho típico do frame Ethernet do SV (~126 bytes p/ 1 ASDU).
SvRate svRate({
  required int samplesPerCycle,
  required int frequency,
  int asduPerFrame = 1,
  int frameBytes = 126,
}) {
  final samplesPerSecond = samplesPerCycle * frequency;
  final packetsPerSecond =
      asduPerFrame > 0 ? (samplesPerSecond / asduPerFrame).round() : 0;
  // banda: pacotes/s × (frame + preâmbulo 8 + IFG 12 bytes) × 8 bits
  final mbps = packetsPerSecond * (frameBytes + 20) * 8 / 1e6;
  return SvRate(
    samplesPerSecond: samplesPerSecond,
    packetsPerSecond: packetsPerSecond,
    estimatedMbps: mbps,
  );
}

// ── Endereçamento: MAC multicast / APPID / VLAN ──────────────────
enum MulticastKind { goose, sampledValues, unknown }

// Classifica um MAC multicast pelas faixas reservadas da IEC 61850-8-1/9-2:
//   GOOSE: 01-0C-CD-01-00-00 .. 01-0C-CD-01-FF-FF
//   SV   : 01-0C-CD-04-00-00 .. 01-0C-CD-04-FF-FF
MulticastKind classifyMulticastMac(String mac) {
  final hex = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  if (hex.length != 12) return MulticastKind.unknown;
  final prefix = hex.substring(0, 8); // 4 primeiros octetos
  if (prefix == '010CCD01') return MulticastKind.goose;
  if (prefix == '010CCD04') return MulticastKind.sampledValues;
  return MulticastKind.unknown;
}

// Verifica se um MAC é multicast (bit menos significativo do 1º octeto = 1).
bool isMulticastMac(String mac) {
  final hex = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  if (hex.length != 12) return false;
  final firstOctet = int.parse(hex.substring(0, 2), radix: 16);
  return (firstOctet & 0x01) == 1;
}

class AddressCheck {
  final bool macValid; // 12 hex e multicast
  final MulticastKind kind;
  final bool appidValid; // 0x0000..0xFFFF (GOOSE 0x0000-0x3FFF, SV 0x4000-0x7FFF típico)
  final bool vlanValid; // 0..4094
  final bool priorityValid; // 0..7

  const AddressCheck({
    required this.macValid,
    required this.kind,
    required this.appidValid,
    required this.vlanValid,
    required this.priorityValid,
  });

  bool get allOk => macValid && appidValid && vlanValid && priorityValid;
}

AddressCheck checkAddressing({
  required String mac,
  required int appid,
  required int vlanId,
  required int priority,
}) {
  return AddressCheck(
    macValid: isMulticastMac(mac) &&
        classifyMulticastMac(mac) != MulticastKind.unknown,
    kind: classifyMulticastMac(mac),
    appidValid: appid >= 0 && appid <= 0xFFFF,
    vlanValid: vlanId >= 0 && vlanId <= 4094,
    priorityValid: priority >= 0 && priority <= 7,
  );
}
