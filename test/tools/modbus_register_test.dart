import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/modbus_register.dart';

void main() {
  group('Modbus — float32', () {
    test('100.0 em ABCD (big-endian): 0x42C8 0x0000', () {
      // 100.0f = 0x42C80000
      final v = registersToFloat32(0x42C8, 0x0000, ByteOrder.abcd);
      expect(v, closeTo(100.0, 1e-6));
    });

    test('mesmos registradores trocados dão 100.0 em CDAB (word-swap)', () {
      // se o medidor manda low word primeiro: reg0=0x0000 reg1=0x42C8
      final v = registersToFloat32(0x0000, 0x42C8, ByteOrder.cdab);
      expect(v, closeTo(100.0, 1e-6));
    });

    test('ordem errada NÃO dá o valor esperado', () {
      final certo = registersToFloat32(0x42C8, 0x0000, ByteOrder.abcd);
      final errado = registersToFloat32(0x42C8, 0x0000, ByteOrder.dcba);
      expect((certo - errado).abs(), greaterThan(1.0));
    });
  });

  group('Modbus — int32 / uint32', () {
    test('0x0001 0x0000 em ABCD = 65536', () {
      expect(registersToInt32(0x0001, 0x0000, ByteOrder.abcd), 65536);
      expect(registersToUint32(0x0001, 0x0000, ByteOrder.abcd), 65536);
    });

    test('valor negativo no int32', () {
      // 0xFFFFFFFF = -1 com sinal, 4294967295 sem sinal
      expect(registersToInt32(0xFFFF, 0xFFFF, ByteOrder.abcd), -1);
      expect(registersToUint32(0xFFFF, 0xFFFF, ByteOrder.abcd), 4294967295);
    });

    test('word-swap troca a ordem das words', () {
      // ABCD: 0x00010002 = 65538 ; CDAB: 0x00020001 = 131073
      expect(registersToUint32(0x0001, 0x0002, ByteOrder.abcd), 0x00010002);
      expect(registersToUint32(0x0001, 0x0002, ByteOrder.cdab), 0x00020001);
    });

    test('byte-swap (BADC) troca bytes dentro de cada word', () {
      // BADC de (0x0102, 0x0304) → bytes B A D C = 02 01 04 03 = 0x02010403
      expect(registersToUint32(0x0102, 0x0304, ByteOrder.badc), 0x02010403);
    });

    test('little-endian (DCBA) inverte tudo', () {
      // DCBA de (0x0102, 0x0304) → D C B A = 04 03 02 01 = 0x04030201
      expect(registersToUint32(0x0102, 0x0304, ByteOrder.dcba), 0x04030201);
    });
  });

  group('Modbus — decode consolidado', () {
    test('decodeRegisters traz float/int/uint e hex coerentes', () {
      final d = decodeRegisters(0x42C8, 0x0000, ByteOrder.abcd);
      expect(d.float32, closeTo(100.0, 1e-6));
      expect(d.uint32, 0x42C80000);
      expect(d.hex, '42 C8 00 00');
    });

    test('decodeAllOrders cobre as 4 ordens', () {
      final all = decodeAllOrders(0x42C8, 0x0000);
      expect(all.keys.length, 4);
      // exatamente uma ordem (ABCD) dá ~100 aqui
      final cemCount = all.values
          .where((d) => (d.float32 - 100.0).abs() < 1e-3)
          .length;
      expect(cemCount, 1);
    });
  });

  group('Modbus — rótulos', () {
    test('labels das ordens', () {
      expect(byteOrderLabel(ByteOrder.abcd), contains('big-endian'));
      expect(byteOrderLabel(ByteOrder.cdab), contains('word-swap'));
    });
  });
}
