import 'package:home_widget/home_widget.dart';
import 'package:neo_brutalism_locket/features/widget/widget_data.dart';

/// Talks to the home-screen widget on the phone.
abstract interface class WidgetBridge {
  /// Shows [post] with its picture, saved at [imagePath] on this phone.
  Future<void> show(WidgetPost post, String imagePath);

  /// Back to the empty state (signed out, or nothing to show).
  Future<void> clear();
}

/// The keys the Android widget (LocketWidgetProvider.kt) reads.
abstract final class WidgetKeys {
  static const postId = 'w_post_id';
  static const name = 'w_name';
  static const caption = 'w_caption';
  static const image = 'w_image';
  static const created = 'w_created';
}

class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge();

  static const _androidName = 'LocketWidgetProvider';
  static const _qualified =
      'com.neobrutalism.neo_brutalism_locket.LocketWidgetProvider';

  Future<void> _refresh() => HomeWidget.updateWidget(
    name: _androidName,
    androidName: _androidName,
    qualifiedAndroidName: _qualified,
  ).then((_) {});

  @override
  Future<void> show(WidgetPost post, String imagePath) async {
    await HomeWidget.saveWidgetData<String>(WidgetKeys.postId, post.postId);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.name, post.name);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.caption, post.caption);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.image, imagePath);
    await HomeWidget.saveWidgetData<int>(WidgetKeys.created, post.createdAtMs);
    await _refresh();
  }

  @override
  Future<void> clear() async {
    for (final key in [
      WidgetKeys.postId,
      WidgetKeys.name,
      WidgetKeys.caption,
      WidgetKeys.image,
    ]) {
      await HomeWidget.saveWidgetData<String>(key, null);
    }
    await HomeWidget.saveWidgetData<int>(WidgetKeys.created, null);
    await _refresh();
  }
}
