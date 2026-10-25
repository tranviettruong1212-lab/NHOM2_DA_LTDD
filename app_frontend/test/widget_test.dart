// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_an_ltdd/screens/home_screen.dart';
import 'package:do_an_ltdd/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders without Firebase initialization', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });

  testWidgets('home screen renders its account and budget summaries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Số dư MoneyMate đang quản lý'), findsOneWidget);
    expect(find.text('Thông báo ngân sách'), findsOneWidget);
    expect(find.text('Giao dịch gần đây'), findsOneWidget);
  });
}
