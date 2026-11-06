import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidtoon/data/atelier.dart';
import 'package:kidtoon/data/coloring_pages.dart';
import 'package:kidtoon/data/parental.dart';

void main() {
  test('planșele: fiecare zonă are contur, iar atingerea găsește zona din față', () {
    expect(coloringPages.length, greaterThanOrEqualTo(8));
    expect(coloringPages.map((p) => p.id).toSet().length, coloringPages.length);
    for (final page in coloringPages) {
      expect(page.regions.length, greaterThanOrEqualTo(6), reason: page.id);
      for (final r in page.regions) {
        expect(r.bounds.isEmpty, isFalse, reason: '${page.id}/${r.name}');
        expect(r.name, isNotEmpty);
      }
      // Fundalul e mereu în spate: un colț al foii îl atinge pe el (sau o zonă de lângă margine).
      expect(page.hit(const Offset(1, 1)), greaterThanOrEqualTo(0), reason: page.id);
    }
    final casa = coloringPages.firstWhere((p) => p.id == 'casa');
    expect(casa.regions[casa.hit(const Offset(45, 66))].name, 'ușa');
    expect(casa.regions[casa.hit(const Offset(86, 14))].name, 'soarele');
    expect(casa.regions[casa.hit(const Offset(50, 5))].name, 'cerul');
  });

  test('telecomanda trece la zona vecină în direcția săgeții', () {
    final casa = coloringPages.firstWhere((p) => p.id == 'casa');
    final door = casa.regions.indexWhere((r) => r.name == 'ușa');
    final up = casa.neighbor(door, 0, -1);
    expect(casa.regions[up].center.dy, lessThan(casa.regions[door].center.dy));
    final right = casa.neighbor(door, 1, 0);
    expect(casa.regions[right].center.dx, greaterThan(casa.regions[door].center.dx));
    // De la soare (dreapta sus) nu mai e nimic mai la dreapta: săgeata iese din foaie.
    final sun = casa.regions.indexWhere((r) => r.name == 'soarele');
    expect(casa.neighbor(sun, 1, 0), -1);
  });

  test('piesele din Construiește: atingerea ține cont de mărime și rotire', () {
    final p = Piece(shape: PieceShape.rect, x: 0.5, y: 0.5, size: 0.2);
    expect(p.contains(0.5, 0.5, 1), isTrue);
    expect(p.contains(0.65, 0.5, 1), isTrue); // dreptunghiul e lat
    expect(p.contains(0.5, 0.6, 1), isFalse);
    p.angle = pi / 2; // acum e înalt
    expect(p.contains(0.5, 0.65, 1), isTrue);
    expect(p.contains(0.65, 0.5, 1), isFalse);
    p.scaleBy(100);
    expect(p.size, Piece.maxSize);
    p.moveBy(2, -2);
    expect((p.x, p.y), (1.0, 0.0));
    for (final t in buildTemplates) {
      expect(t.make().every((x) => x.x >= 0 && x.x <= 1 && x.y >= 0 && x.y <= 1), isTrue, reason: t.title);
    }
  });

  test('galeria salvează și listează lucrările, cele noi primele', () async {
    final dir = await Directory.systemTemp.createTemp('art');
    final store = ArtStore(dir);
    await store.save('desen', Uint8List.fromList([1, 2, 3]), DateTime(2026, 1, 2, 3, 4, 5));
    await store.save('colorat', Uint8List.fromList([4]), DateTime(2026, 5, 1, 10, 0, 0));
    final files = await store.list();
    expect(files.map((f) => f.path.split('/').last), ['colorat_20260501_100000.png', 'desen_20260102_030405.png']);
    expect(ArtStore.kindOf(files.first), contains('Colorat'));
    await dir.delete(recursive: true);
  });

  test('poarta părinților: înmulțirea are 4 variante, una corectă', () {
    for (var seed = 0; seed < 50; seed++) {
      final q = ParentQuestion.random(Random(seed));
      final c = q.choices(Random(seed));
      expect(c.length, 4);
      expect(c.toSet().length, 4);
      expect(c.where(q.check).length, 1);
      expect(c.every((n) => n > 0), isTrue);
    }
    expect(ParentPin.isValid('1234'), isTrue);
    expect(ParentPin.isValid('12a4'), isFalse);
    expect(ParentPin.isValid('123'), isFalse);
  });
}
