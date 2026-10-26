import 'package:neo_brutalism_locket/features/search/search_query.dart';

/// Searches about what a person IS (sexual orientation, gender identity,
/// religion, race) are not looked up in the photos. A photo model cannot know
/// these things; what it does is match the word with whoever looks the most
/// like a stereotype of it, and the search would then label a real friend's
/// photo with something it knows nothing about.
///
/// Such a search still finds captions and places that contain the words (the
/// author wrote those), only the picture part is skipped. Extend the lists
/// here; terms are matched as whole words, without accents.
bool asksAboutPeople(String text) => _terms.hasMatch(foldAccents(text));

final _terms = RegExp(
  '(?<![a-z0-9])(?:'
  // sexual orientation, gender identity
  'gays?|lesbians?|bisexuals?|homosexuals?|lgbtq?\\+?|queers?|transgenders?|'
  'dong tinh|be de|chuyen gioi|'
  // religion of people (not places or objects: a pagoda is just a picture)
  'muslims?|jewish|christians?|buddhists?|hindus?|atheists?|hoi giao|do thai|'
  'nguoi theo dao|'
  // race, ethnicity
  '(?:black|white|asian|latino|arab|indian) '
  '(?:people|persons?|m[ae]n|wom[ae]n|guys?|girls?)|'
  'nguoi da (?:den|trang|mau)'
  ')(?![a-z0-9])',
);
