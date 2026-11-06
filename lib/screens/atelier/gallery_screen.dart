import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/atelier.dart';
import '../../theme.dart';
import '../../widgets/kid_tile.dart';
import 'common.dart';

/// Galeria mea: tot ce a colorat, desenat și construit copilul, cele mai noi primele.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _store = ArtStore();
  List<File>? _files;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await _store.list();
      if (mounted) setState(() => _files = f);
    } catch (_) {
      if (mounted) setState(() => _files = []);
    }
  }

  Future<void> _open(File f) async {
    final deleted = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _ArtViewer(file: f)));
    if (deleted == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Scaffold(
      appBar: atelierBar(context, '🖼️ Galeria mea', const []),
      body: files == null
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Încă nu ai lucrări.\nColorează, desenează sau construiește ceva și apasă ⭐ Salvează!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: KidColors.textDim),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth > 1100 ? 5 : (box.maxWidth > 620 ? 4 : 2);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: files.length,
                  itemBuilder: (context, i) => KidTile(
                    color: [KidColors.purple, KidColors.pink, KidColors.teal, KidColors.orange][i % 4],
                    autofocus: i == 0,
                    onTap: () => _open(files[i]),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(files[i], fit: BoxFit.cover, width: double.infinity, cacheWidth: 400),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ArtStore.kindOf(files[i]),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ArtViewer extends StatelessWidget {
  const _ArtViewer({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: atelierBar(context, ArtStore.kindOf(file), [
        IconButton.filledTonal(
          tooltip: 'Șterge',
          icon: const Icon(Icons.delete_rounded),
          onPressed: () async {
            if (!await confirmClear(context, 'Ștergem lucrarea din galerie?')) return;
            try {
              await file.delete();
            } catch (_) {}
            if (context.mounted) Navigator.pop(context, true);
          },
        ),
      ]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Focus(
            autofocus: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
