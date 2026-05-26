import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  TESTES DE WIDGET — MainShellScreen (isolado, sem Firebase)
//  Usa overrides de providers para evitar dependências externas.
// ─────────────────────────────────────────────────────────────────

/// Widget stub que substitui cada tela filha nos testes.
class _StubScreen extends StatelessWidget {
  final String label;
  const _StubScreen(this.label);

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(label, key: Key('screen_$label')));
}

/// Versão testável do MainShellScreen (sem Firebase/Firestore).
class _TestableShell extends ConsumerStatefulWidget {
  const _TestableShell();

  @override
  ConsumerState<_TestableShell> createState() => _TestableShellState();
}

class _TestableShellState extends ConsumerState<_TestableShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _StubScreen('Início'),
    _StubScreen('Trilha'),
    _StubScreen('Ranking'),
    _StubScreen('Perfil'),
    _StubScreen('Loja'),
  ];

  @override
  Widget build(BuildContext context) {
    final isTestMode = ref.watch(devModeProvider);

    return Scaffold(
      body: isTestMode
          ? Column(
              children: [
                Container(
                  key: const Key('dev_mode_banner'),
                  color: const Color(0xFF2A1800),
                  child: const Text('TEST MODE'),
                ),
                Expanded(child: _screens[_currentIndex]),
              ],
            )
          : _screens[_currentIndex],
      bottomNavigationBar: Semantics(
        label: 'Barra de navegação inferior',
        explicitChildNodes: true,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, semanticLabel: 'Ir para Início'),
              label: 'Início',
              tooltip: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.route_outlined, semanticLabel: 'Ir para Trilha'),
              label: 'Trilha',
              tooltip: 'Trilha',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined, semanticLabel: 'Ir para Ranking'),
              label: 'Ranking',
              tooltip: 'Ranking',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, semanticLabel: 'Ir para Perfil'),
              label: 'Perfil',
              tooltip: 'Perfil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.store_outlined, semanticLabel: 'Ir para Loja'),
              label: 'Loja',
              tooltip: 'Loja',
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('MainShellScreen (testável)', () {
    Widget buildShell() {
      return ProviderScope(
        child: const MaterialApp(home: _TestableShell()),
      );
    }

    testWidgets('renderiza tela inicial (Início)', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(find.byKey(const Key('screen_Início')), findsOneWidget);
    });

    testWidgets('NavBar tem 5 itens', (tester) async {
      await tester.pumpWidget(buildShell());
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      // 5 items = 5 labels visíveis
      expect(find.text('Início'), findsAtLeastNWidgets(1));
      expect(find.text('Trilha'), findsAtLeastNWidgets(1));
      expect(find.text('Ranking'), findsAtLeastNWidgets(1));
      expect(find.text('Perfil'), findsAtLeastNWidgets(1));
      expect(find.text('Loja'), findsAtLeastNWidgets(1));
    });

    testWidgets('navegação via tap muda tela ativa', (tester) async {
      await tester.pumpWidget(buildShell());

      // Inicia em Início
      expect(find.byKey(const Key('screen_Início')), findsOneWidget);

      // Toca em Trilha
      await tester.tap(find.text('Trilha').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_Trilha')), findsOneWidget);
      expect(find.byKey(const Key('screen_Início')), findsNothing);
    });

    testWidgets('navega para Ranking via tap', (tester) async {
      await tester.pumpWidget(buildShell());

      await tester.tap(find.text('Ranking').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_Ranking')), findsOneWidget);
    });

    testWidgets('devMode DESATIVADO — sem banner', (tester) async {
      await tester.pumpWidget(buildShell());

      expect(find.byKey(const Key('dev_mode_banner')), findsNothing);
    });

    testWidgets('devMode ATIVADO — exibe banner', (tester) async {
      await tester.pumpWidget(buildShell());

      // Ativa dev mode
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_TestableShell)),
      );
      container.read(devModeProvider.notifier).activate();
      await tester.pump();

      expect(find.byKey(const Key('dev_mode_banner')), findsOneWidget);
      expect(find.text('TEST MODE'), findsOneWidget);
    });

    testWidgets('Semantics presente na barra de navegação', (tester) async {
      await tester.pumpWidget(buildShell());

      expect(
        find.bySemanticsLabel('Barra de navegação inferior'),
        findsOneWidget,
      );
    });

    testWidgets('ícones da NavBar estão presentes (5 ícones)', (tester) async {
      await tester.pumpWidget(buildShell());

      // Verifica que os ícones Outlined estão presentes (estado não selecionado)
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.store_outlined), findsOneWidget);
    });
  });
}
