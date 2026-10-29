import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:my_app/main.dart';

void main() {
  setUpAll(() {
    // 测试环境不联网拉取字体，直接用本地回退字体
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('主页固定搜索框与只显示图标的底部 tab', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('搜索歌曲 / 歌手'), findsOneWidget);
    // 底部 tab 只保留图标
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.home),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.favorite_border),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.favorite_border),
      ),
    );
    await tester.pump();

    expect(find.text('还没有收藏，点击歌曲右侧的 ♡ 收藏'), findsOneWidget);
  });
}
