# Dalalak Company Website (Flutter Web)

لوحة تحكم احترافية لشركات السياحة مبنية باستخدام Flutter Web، وتغطي إدارة التشغيل اليومي بالكامل.

## الصفحات المنفذة

1. تسجيل الدخول (Email + Password + Role: Company/Admin/Staff)
2. Dashboard رئيسية مع Cards ومؤشرات ورسوم مبسطة
3. إدارة الرحلات Tours Management
4. إنشاء رحلة جديدة + Smart Features (طقس/وقت مناسب/تنبيه حرارة)
5. إدارة المرشدين
6. إدارة الحجوزات
7. إدارة العملاء
8. Live Translation
9. Reports / Analytics
10. Reviews
11. Settings (بيانات الشركة/ساعات العمل/طرق الدفع)
12. Notifications

## هيكل الواجهة

- Sidebar: Dashboard, Tours, Guides, Bookings, Customers, Live Translation, Reports, Reviews, Settings, Notifications
- Topbar: عنوان الصفحة + إشعارات + صورة الحساب
- تصميم متجاوب: Desktop + Mobile Drawer

## تشغيل المشروع

> ملاحظة: بيئة التطوير الحالية لا تحتوي Flutter SDK. للتشغيل محليًا:

1. ثبّت Flutter (قناة stable)
2. من داخل المشروع نفّذ:

```bash
flutter pub get
flutter run -d chrome
```

أو لبناء نسخة ويب إنتاجية:

```bash
flutter build web
```

## أهم الملفات

- lib/main.dart
- lib/app.dart
- lib/layout/dashboard_shell.dart
- lib/layout/sidebar.dart
- lib/layout/topbar.dart
- lib/pages/
- lib/theme/app_theme.dart
- lib/widgets/common_widgets.dart