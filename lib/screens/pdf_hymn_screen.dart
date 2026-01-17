import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfx/pdfx.dart';

import '../../widgets/audio_controls.dart';

class PdfHymnScreen extends StatefulWidget {
  const PdfHymnScreen({
    super.key,
    required this.title,
    required this.pdfAssetPath,
    required this.sharedPlayer,
  });

  final String title;
  final String pdfAssetPath;
  final AudioPlayer sharedPlayer;

  @override
  State<PdfHymnScreen> createState() => _PdfHymnScreenState();
}

class _PdfHymnScreenState extends State<PdfHymnScreen> {
  late final PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openAsset(widget.pdfAssetPath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          AudioControls(player: widget.sharedPlayer),
          const Divider(height: 1),
          Expanded(
            child: PdfViewPinch(
              controller: _pdfController,
            ),
          ),
        ],
      ),
    );
  }
}
