import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/iec61850.dart';

void main() {
  group('GOOSE — sequência de retransmissão', () {
    test('dobra de T1 até estabilizar em T0', () {
      final seq = gooseRetransmissionSequence(t1Ms: 4, t0Ms: 1000);
      // 4, 8, 16, 32, 64, 128, 256, 512, 1000 (último é T0)
      expect(seq.first, 4);
      expect(seq.last, 1000);
      // monotônica crescente até T0
      for (var i = 1; i < seq.length; i++) {
        expect(seq[i], greaterThan(seq[i - 1]));
      }
      // não ultrapassa T0
      expect(seq.every((t) => t <= 1000), isTrue);
    });

    test('T1 já ≥ T0 → só T0', () {
      final seq = gooseRetransmissionSequence(t1Ms: 2000, t0Ms: 1000);
      expect(seq, [1000]);
    });

    test('entradas inválidas → vazio', () {
      expect(gooseRetransmissionSequence(t1Ms: 0, t0Ms: 1000), isEmpty);
      expect(gooseRetransmissionSequence(t1Ms: 4, t0Ms: 0), isEmpty);
    });
  });

  group('GOOSE — requisito de tempo', () {
    test('trip tipo 1A: 2,5 ms passa, 4 ms falha', () {
      expect(gooseTimeOk(measuredMs: 2.5, maxTransferMs: 3), isTrue);
      expect(gooseTimeOk(measuredMs: 4, maxTransferMs: 3), isFalse);
    });

    test('catálogo de classes tem o trip de 3 ms', () {
      final trip = gooseMessageClasses.firstWhere((c) => c.name.contains('1A'));
      expect(trip.maxTransferMs, 3);
    });
  });

  group('SV — taxa de amostragem', () {
    test('80 amostras/ciclo @ 60 Hz → 4800 amostras/s e pacotes/s', () {
      final r = svRate(samplesPerCycle: 80, frequency: 60);
      expect(r.samplesPerSecond, 4800);
      expect(r.packetsPerSecond, 4800); // 1 ASDU/frame
      expect(r.estimatedMbps, greaterThan(0));
    });

    test('256 amostras/ciclo @ 50 Hz → 12800 amostras/s', () {
      final r = svRate(samplesPerCycle: 256, frequency: 50);
      expect(r.samplesPerSecond, 12800);
    });

    test('agregação de ASDUs reduz pacotes/s', () {
      final um = svRate(samplesPerCycle: 80, frequency: 60, asduPerFrame: 1);
      final oito = svRate(samplesPerCycle: 80, frequency: 60, asduPerFrame: 8);
      expect(oito.packetsPerSecond, lessThan(um.packetsPerSecond));
      expect(oito.packetsPerSecond, 600); // 4800/8
    });
  });

  group('Endereçamento — MAC multicast', () {
    test('classifica GOOSE e SV pelas faixas reservadas', () {
      expect(classifyMulticastMac('01-0C-CD-01-00-01'), MulticastKind.goose);
      expect(classifyMulticastMac('01:0C:CD:04:00:0A'),
          MulticastKind.sampledValues);
      expect(classifyMulticastMac('01-0C-CD-02-00-01'), MulticastKind.unknown);
    });

    test('aceita separadores variados e ignora maiúsc/minúsc', () {
      expect(classifyMulticastMac('010ccd010001'), MulticastKind.goose);
    });

    test('detecta bit multicast', () {
      expect(isMulticastMac('01-0C-CD-01-00-01'), isTrue);
      // 1º octeto par (00) → não multicast
      expect(isMulticastMac('00-0C-CD-01-00-01'), isFalse);
    });

    test('MAC malformado → não multicast / desconhecido', () {
      expect(isMulticastMac('01-0C-CD'), isFalse);
      expect(classifyMulticastMac('xyz'), MulticastKind.unknown);
    });
  });

  group('Endereçamento — checagem completa', () {
    test('GOOSE válido passa em tudo', () {
      final c = checkAddressing(
        mac: '01-0C-CD-01-00-01', appid: 0x0001, vlanId: 100, priority: 4,
      );
      expect(c.kind, MulticastKind.goose);
      expect(c.allOk, isTrue);
    });

    test('VLAN e prioridade fora de faixa reprovam', () {
      final c = checkAddressing(
        mac: '01-0C-CD-01-00-01', appid: 0x0001, vlanId: 5000, priority: 9,
      );
      expect(c.vlanValid, isFalse);
      expect(c.priorityValid, isFalse);
      expect(c.allOk, isFalse);
    });

    test('MAC não-61850 reprova o mac', () {
      final c = checkAddressing(
        mac: '00-11-22-33-44-55', appid: 1, vlanId: 0, priority: 0,
      );
      expect(c.macValid, isFalse);
      expect(c.allOk, isFalse);
    });
  });
}
