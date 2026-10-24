import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:neo_brutalism_locket/features/widget/widget_data.dart';

/// Talks to the home-screen widget on the phone.
abstract interface class WidgetBridge {
  /// Shows [post] with its picture, saved at [imagePath] on this phone, on
  /// the widgets set to [source] (see [allSource]).
  Future<void> show(
    WidgetPost post,
    String imagePath, {
    String source = allSource,
  });

  /// Back to the empty state (signed out, or nothing to show): the main
  /// widget and every one of [sources].
  Future<void> clear({Iterable<String> sources = const []});

  /// The sources the widgets on the home screen are set to, besides
  /// [allSource]. Only these are worth downloading pictures for.
  Future<Set<String>> activeSources();

  /// The friends and groups a widget can be set to, for its picker.
  Future<void> publishChoices(List<WidgetChoice> choices);
}

/// The keys the Android widget (LocketWidgetProvider.kt) reads.
abstract final class WidgetKeys {
  static const postId = 'w_post_id';
  static const name = 'w_name';
  static const caption = 'w_caption';
  static const image = 'w_image';
  static const created = 'w_created';

  /// Comma-separated sources the placed widgets follow (kept by the Android
  /// side as widgets are set up and removed).
  static const active = 'w_active';

  /// JSON list of what a widget can follow, for the picker.
  static const choices = 'w_choices';

  /// The key of [field] (one of the names above) for [source]. The main
  /// widget keeps the original names.
  static String of(String source, String field) =>
      source == allSource ? field : 'ws_${source}_$field';
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
  Future<void> show(
    WidgetPost post,
    String imagePath, {
    String source = allSource,
  }) async {
    Future<void> save<T>(String field, T value) =>
        HomeWidget.saveWidgetData<T>(WidgetKeys.of(source, field), value);
    await save<String>(WidgetKeys.postId, post.postId);
    await save<String>(WidgetKeys.name, post.name);
    await save<String>(WidgetKeys.caption, post.caption);
    await save<String>(WidgetKeys.image, imagePath);
    await save<int>(WidgetKeys.created, post.createdAtMs);
    await _refresh();
  }

  @override
  Future<void> clear({Iterable<String> sources = const []}) async {
    for (final source in [allSource, ...sources]) {
      for (final field in [
        WidgetKeys.postId,
        WidgetKeys.name,
        WidgetKeys.caption,
        WidgetKeys.image,
      ]) {
        await HomeWidget.saveWidgetData<String>(
          WidgetKeys.of(source, field),
          null,
        );
      }
      await HomeWidget.saveWidgetData<int>(
        WidgetKeys.of(source, WidgetKeys.created),
        null,
      );
    }
    // The names of friends and groups must not outlive the account.
    await HomeWidget.saveWidgetData<String>(WidgetKeys.choices, null);
    await _refresh();
  }

  @override
  Future<Set<String>> activeSources() async {
    final stored = await HomeWidget.getWidgetData<String>(WidgetKeys.active);
    return {
      for (final key in (stored ?? '').split(','))
        if (key.isNotEmpty && key != allSource) key,
    };
  }

  @override
  Future<void> publishChoices(List<WidgetChoice> choices) async {
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.choices,
      jsonEncode([
        for (final choice in choices) {'k': choice.key, 'l': choice.label},
      ]),
    );
  }
}
