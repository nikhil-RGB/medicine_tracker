import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';
import 'app_data_repository.dart';
import 'custom_catalog_repository.dart';
import 'intake_repository.dart';
import 'json_store.dart';
import 'reference_catalog_service.dart';
import 'settings_service.dart';

/// All long-lived services + repositories, wired up once at boot.
class AppServices {
  final JsonStore store;
  final SettingsService settings;
  final AppDataRepository appData;
  final IntakeRepository intake;
  final CustomCatalogRepository custom;
  final ReferenceCatalogService reference;
  final NotificationService notifications;
  final NotificationScheduler scheduler;

  AppServices({
    required this.store,
    required this.settings,
    required this.appData,
    required this.intake,
    required this.custom,
    required this.reference,
    required this.notifications,
    required this.scheduler,
  });

  static Future<AppServices> bootstrap() async {
    final store = await JsonStore.open();
    final settings = await SettingsService.open();
    final appData = AppDataRepository(store);
    final intake = IntakeRepository(store);
    final custom = CustomCatalogRepository(store);
    final reference = ReferenceCatalogService();
    final notifications = NotificationService();

    await Future.wait([
      appData.load(),
      intake.load(),
      custom.load(),
      reference.loadIndex(),
      notifications.init(),
    ]);

    final scheduler = NotificationScheduler(notifications);
    return AppServices(
      store: store,
      settings: settings,
      appData: appData,
      intake: intake,
      custom: custom,
      reference: reference,
      notifications: notifications,
      scheduler: scheduler,
    );
  }
}
