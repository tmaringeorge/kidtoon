import 'dart:math';

import 'models.dart';

/// O întrebare pentru părinți („Cât face 7 × 8?”), ușor de rezolvat de un adult,
/// greu pentru un copil mic. Se răspunde din butoane mari (merge și cu telecomanda).
class ParentQuestion {
  ParentQuestion(this.a, this.b);

  factory ParentQuestion.random([Random? rnd]) {
    final r = rnd ?? Random();
    return ParentQuestion(3 + r.nextInt(7), 4 + r.nextInt(6));
  }

  final int a, b;
  int get answer => a * b;
  String get text => 'Cât face $a × $b?';

  /// Patru variante, una corectă, amestecate.
  List<int> choices([Random? rnd]) {
    final r = rnd ?? Random();
    final set = <int>{answer};
    final near = [answer + a, answer - b, answer + 1 + r.nextInt(4), answer - 2 - r.nextInt(5), answer + 10];
    for (final n in near..shuffle(r)) {
      if (set.length >= 4) break;
      if (n > 0) set.add(n);
    }
    return set.toList()..shuffle(r);
  }

  bool check(int value) => value == answer;
}

/// Codul PIN al părinților: 4 cifre. Gol = doar întrebarea de mai sus.
class ParentPin {
  static bool isValid(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
}

/// Ce posturi vede copilul la „Desene TV”.
class KidFilter {
  /// Categoriile potrivite pentru copii (deja traduse în română de parserul M3U).
  static const kidCategories = {'Copii', 'Educație', 'Familie'};

  static bool isForKids(Channel c) => c.categories.any(kidCategories.contains);

  /// [kidsOnly] păstrează doar desenele și educativele; [hidden] sunt posturile ascunse de părinte.
  static List<Channel> apply(List<Channel> all, {required bool kidsOnly, Set<String> hidden = const {}}) =>
      all.where((c) => !hidden.contains(c.key) && (!kidsOnly || isForKids(c))).toList();

  static String get label => kidCategories.join(', ');
}
