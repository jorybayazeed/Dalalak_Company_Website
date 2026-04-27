import 'package:dalalak_company_website/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DalelakCompanyApp());

    expect(find.text('Login to Dashboard'), findsOneWidget);
    expect(find.text('Tourism Company Portal'), findsOneWidget);
  });
}
