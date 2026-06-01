import 'dart:typed_data';

// Conversão de registradores Modbus — junta 2 registradores de 16 bits em um
// valor de 32 bits (float ou int) com a ordem de byte/word correta.
//
// O problema clássico de campo: o medidor entrega 2 registradores e o valor
// "vem errado" porque a ordem de bytes/words diverge. As 4 ordens usuais:
//   • ABCD — big-endian puro (high word primeiro, high byte primeiro)
//   • CDAB — word-swap (low word primeiro) — comum em muitos medidores
//   • BADC — byte-swap dentro de cada word
//   • DCBA — little-endian puro
// (A/B = bytes do 1º registrador lido; C/D = bytes do 2º registrador lido.)

enum ByteOrder { abcd, cdab, badc, dcba }

String byteOrderLabel(ByteOrder o) {
  switch (o) {
    case ByteOrder.abcd:
      return 'ABCD (big-endian)';
    case ByteOrder.cdab:
      return 'CDAB (word-swap)';
    case ByteOrder.badc:
      return 'BADC (byte-swap)';
    case ByteOrder.dcba:
      return 'DCBA (little-endian)';
  }
}

// Monta os 4 bytes [A,B,C,D] na ordem física a partir de reg0 e reg1 (16 bits).
// reg0 = primeiro registrador lido, reg1 = segundo.
Uint8List _orderedBytes(int reg0, int reg1, ByteOrder order) {
  final a = (reg0 >> 8) & 0xFF; // high byte do reg0
  final b = reg0 & 0xFF; // low byte do reg0
  final c = (reg1 >> 8) & 0xFF; // high byte do reg1
  final d = reg1 & 0xFF; // low byte do reg1
  switch (order) {
    case ByteOrder.abcd:
      return Uint8List.fromList([a, b, c, d]);
    case ByteOrder.cdab:
      return Uint8List.fromList([c, d, a, b]);
    case ByteOrder.badc:
      return Uint8List.fromList([b, a, d, c]);
    case ByteOrder.dcba:
      return Uint8List.fromList([d, c, b, a]);
  }
}

// Float IEEE-754 de 32 bits a partir de 2 registradores.
double registersToFloat32(int reg0, int reg1, ByteOrder order) {
  final bytes = _orderedBytes(reg0, reg1, order);
  return ByteData.sublistView(bytes).getFloat32(0, Endian.big);
}

// Inteiro com sinal de 32 bits.
int registersToInt32(int reg0, int reg1, ByteOrder order) {
  final bytes = _orderedBytes(reg0, reg1, order);
  return ByteData.sublistView(bytes).getInt32(0, Endian.big);
}

// Inteiro sem sinal de 32 bits.
int registersToUint32(int reg0, int reg1, ByteOrder order) {
  final bytes = _orderedBytes(reg0, reg1, order);
  return ByteData.sublistView(bytes).getUint32(0, Endian.big);
}

class ModbusDecode {
  final double float32;
  final int int32;
  final int uint32;
  final String hex; // representação dos 4 bytes na ordem aplicada

  const ModbusDecode({
    required this.float32,
    required this.int32,
    required this.uint32,
    required this.hex,
  });
}

ModbusDecode decodeRegisters(int reg0, int reg1, ByteOrder order) {
  final bytes = _orderedBytes(reg0, reg1, order);
  final bd = ByteData.sublistView(bytes);
  final hex = bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
  return ModbusDecode(
    float32: bd.getFloat32(0, Endian.big),
    int32: bd.getInt32(0, Endian.big),
    uint32: bd.getUint32(0, Endian.big),
    hex: hex,
  );
}

// Decodifica em TODAS as ordens de uma vez — útil para descobrir qual a correta
// quando o valor esperado é conhecido ("qual ordem dá 100,0?").
Map<ByteOrder, ModbusDecode> decodeAllOrders(int reg0, int reg1) {
  return {
    for (final o in ByteOrder.values) o: decodeRegisters(reg0, reg1, o),
  };
}
