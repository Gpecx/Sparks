import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';

List<String> _b(String prefix, int count) => [
      '${prefix}_intro',
      for (int i = 1; i <= count; i++) '${prefix}_l$i',
      '${prefix}_eval'
    ];

String _getTitle(String id) {
  if (id.endsWith('_intro')) return 'Introdução';
  if (id.endsWith('_eval')) return 'Avaliação';
  final p = id.split('_l');
  if (p.length == 2) return 'Lição ${p[1]}';
  return 'Lição';
}

Future<void> seedCurriculum() async {
  final fs = FirebaseFirestore.instance;
  var batch = fs.batch();
  int opCount = 0;

  Future<void> commitBatch() async {
    if (opCount >= 450) {
      await batch.commit();
      batch = fs.batch();
      opCount = 0;
    }
  }

  void addOp() => opCount++;

  final data = [
    {
      'id': 'normas',
      'title': 'Normas Regulamentadoras',
      'icon': 'gavel',
      'color': '#00C402',
      'gradientEnd': '#1D5F31',
      'order': 1,
      'modules': [
        {
          'id': 'nr10',
          'title': 'NR-10 · Eletricidade',
          'color': '#00C402',
          'order': 1,
          'isLocked': false,
          'xpReward': 500,
          'spReward': 200,
          'tensionLevelRequired': 'BT',
          'requiredModuleId': null,
          'lessons': _b('nr10', 10),
        },
        {
          'id': 'nr12',
          'title': 'NR-12 · Máquinas',
          'order': 2,
          'isLocked': true,
          'xpReward': 400,
          'spReward': 160,
          'requiredModuleId': 'nr10',
          'lessons': _b('nr12', 8),
        },
        {
          'id': 'nr33',
          'title': 'NR-33 · Espaço Confinado',
          'order': 3,
          'isLocked': true,
          'xpReward': 350,
          'spReward': 140,
          'requiredModuleId': 'nr12',
          'lessons': _b('nr33', 6),
        },
        {
          'id': 'nr35',
          'title': 'NR-35 · Trabalho em Altura',
          'order': 4,
          'isLocked': true,
          'xpReward': 400,
          'spReward': 160,
          'requiredModuleId': 'nr33',
          'lessons': _b('nr35', 8),
        },
      ]
    },
    {
      'id': 'seletividade',
      'title': 'Seletividade',
      'icon': 'account_tree',
      'color': '#42A5F5',
      'order': 2,
      'modules': [
        {
          'id': 'sel_intro',
          'title': 'Fundamentos de Seletividade',
          'isLocked': false,
          'requiredModuleId': null,
          'lessons': _b('sel_intro', 8),
        },
        {
          'id': 'sel_curvas',
          'title': 'Curvas de Atuação',
          'isLocked': true,
          'requiredModuleId': 'sel_intro',
          'lessons': _b('sel_curvas', 6),
        },
        {
          'id': 'sel_disj',
          'title': 'Seletividade entre Disjuntores',
          'isLocked': true,
          'requiredModuleId': 'sel_curvas',
          'lessons': _b('sel_disj', 7),
        },
      ]
    },
    {
      'id': 'seguranca',
      'title': 'Segurança Básica',
      'icon': 'security',
      'color': '#FF9800',
      'order': 3,
      'modules': [
        {
          'id': 'seg_epis',
          'title': 'EPIs e EPCs',
          'isLocked': false,
          'requiredModuleId': null,
          'lessons': _b('seg_epis', 8),
        },
        {
          'id': 'seg_socorros',
          'title': 'Primeiros Socorros',
          'isLocked': true,
          'requiredModuleId': 'seg_epis',
          'lessons': _b('seg_socorros', 6),
        },
        {
          'id': 'seg_loto',
          'title': 'Bloqueio e Etiquetagem',
          'isLocked': true,
          'requiredModuleId': 'seg_socorros',
          'lessons': _b('seg_loto', 5),
        },
      ]
    },
    {
      'id': 'bt',
      'title': 'BT · Baixa Tensão',
      'icon': 'electrical_services',
      'color': '#66BB6A',
      'order': 4,
      'tensionLevelRequired': 'BT',
      'modules': [
        {
          'id': 'bt_res',
          'title': 'Instalações Residenciais',
          'isLocked': false,
          'requiredModuleId': null,
          'lessons': _b('bt_res', 10),
        },
        {
          'id': 'bt_ind',
          'title': 'Instalações Industriais BT',
          'isLocked': true,
          'requiredModuleId': 'bt_res',
          'lessons': _b('bt_ind', 8),
        },
      ]
    },
    {
      'id': 'mt',
      'title': 'MT · Média Tensão',
      'icon': 'bolt',
      'color': '#AB47BC',
      'order': 5,
      'tensionLevelRequired': 'MT',
      'modules': [
        {
          'id': 'mt_sub',
          'title': 'Subestações de Média Tensão',
          'isLocked': false,
          'requiredModuleId': null,
          'lessons': _b('mt_sub', 10),
        },
        {
          'id': 'mt_prot',
          'title': 'Proteção em MT',
          'isLocked': true,
          'requiredModuleId': 'mt_sub',
          'lessons': _b('mt_prot', 8),
        },
      ]
    },
    {
      'id': 'at',
      'title': 'AT · Alta Tensão',
      'icon': 'flash_on',
      'color': '#EF5350',
      'order': 6,
      'tensionLevelRequired': 'AT',
      'modules': [
        {
          'id': 'at_lin',
          'title': 'Linhas de Transmissão',
          'isLocked': false,
          'requiredModuleId': null,
          'lessons': _b('at_lin', 10),
        },
        {
          'id': 'at_man',
          'title': 'Manobras em AT',
          'isLocked': true,
          'requiredModuleId': 'at_lin',
          'lessons': _b('at_man', 8),
        },
      ]
    },
  ];

  for (final cat in data) {
    final catId = cat['id'] as String;
    final catRef = fs.collection(FS.categories).doc(catId);
    
    batch.set(catRef, {
      'id': catId,
      'title': cat['title'],
      'icon': cat['icon'],
      'color': cat['color'],
      if (cat.containsKey('gradientEnd')) 'gradientEnd': cat['gradientEnd'],
      'order': cat['order'],
      if (cat.containsKey('tensionLevelRequired')) 'tensionLevelRequired': cat['tensionLevelRequired'],
    });
    addOp();
    await commitBatch();

    final modules = cat['modules'] as List;
    int modOrder = 1;
    
    for (final mod in modules) {
      final modId = mod['id'] as String;
      final modRef = catRef.collection(FS.modules).doc(modId);
      
      batch.set(modRef, {
        'id': modId,
        'title': mod['title'],
        'order': mod.containsKey('order') ? mod['order'] : modOrder,
        'isLocked': mod['isLocked'],
        'xpReward': mod['xpReward'] ?? 300,
        'spReward': mod['spReward'] ?? 120,
        if (mod.containsKey('color')) 'color': mod['color'],
        if (mod.containsKey('requiredModuleId')) 'requiredModuleId': mod['requiredModuleId'],
        if (mod.containsKey('tensionLevelRequired')) 'tensionLevelRequired': mod['tensionLevelRequired'],
      });
      addOp();
      await commitBatch();
      modOrder++;

      final lessons = mod['lessons'] as List<String>;
      int lesOrder = 1;
      
      for (final lesId in lessons) {
        final isEval = lesId.endsWith('_eval');
        final lesRef = modRef.collection(FS.lessons).doc(lesId);
        
        batch.set(lesRef, {
          'id': lesId,
          'order': lesOrder,
          'title': _getTitle(lesId),
          'type': isEval ? 'eval' : 'lesson',
          'xpReward': isEval ? 150 : 50,
          'spReward': isEval ? 60 : 20,
          'isActive': true,
          'content': '',
        });
        addOp();
        await commitBatch();
        lesOrder++;
      }
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }
}
