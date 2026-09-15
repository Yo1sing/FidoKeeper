import 'package:fidokeeper/widgets/action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    required ValueChanged<String> onSelected,
    bool enabled = true,
    bool connected = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: ActionMenuButton(
              tooltip: '更多操作',
              enabled: enabled,
              items: [
                const ActionMenuItem(
                  value: 'details',
                  label: '详情',
                  icon: Icons.info_outline,
                ),
                if (connected)
                  const ActionMenuItem(
                    value: 'disconnect',
                    label: '断开连接',
                    icon: Icons.link_off,
                  ),
                const ActionMenuItem(
                  value: 'hide',
                  label: '隐藏设备',
                  icon: Icons.visibility_off_outlined,
                ),
                const ActionMenuItem(
                  value: 'reset',
                  label: '重置设备…',
                  icon: Icons.restart_alt,
                  destructive: true,
                ),
              ],
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('自绘菜单弹出条目并选择，不使用原生 PopupMenu', (tester) async {
    String? selected;
    await pumpMenu(tester, onSelected: (value) => selected = value);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('详情'), findsOneWidget);
    expect(find.text('隐藏设备'), findsOneWidget);
    expect(find.text('重置设备…'), findsOneWidget);
    expect(find.text('断开连接'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byType(ClipRRect), findsWidgets);
    final path = actionMenuPanelPath(size: const Size(188, 80), radius: 16);
    // 圆角矩形，没有指向按钮的三角箭头。
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(const Offset(94, 16)), isTrue);
    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();
    expect(selected, 'details');
    expect(find.text('详情'), findsNothing);
  });

  testWidgets('已连接时菜单含断开，点空白关闭', (tester) async {
    await pumpMenu(tester, onSelected: (_) {}, connected: true);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('断开连接'), findsOneWidget);
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(find.text('详情'), findsNothing);
  });

  testWidgets('禁用时不弹出菜单', (tester) async {
    await pumpMenu(tester, onSelected: (_) {}, enabled: false);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('详情'), findsNothing);
  });

  testWidgets('打开首帧和缩放过程中都有模糊，且不包在 Opacity 里', (tester) async {
    await pumpMenu(tester, onSelected: (_) {});
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(Transform), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
