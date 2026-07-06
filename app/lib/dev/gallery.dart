// my-flopy — dev gallery: every design-system widget in one scroll, for
// eyeballing parity against design/ (the Claude Design mirror). Not part of
// the product UI; reachable as the home screen until the app shell lands.

import 'package:flutter/material.dart';

import '../design/mf_icons.dart';
import '../design/mf_theme.dart';
import '../design/widgets/mf_app_header.dart';
import '../design/widgets/mf_button.dart';
import '../design/widgets/mf_chip.dart';
import '../design/widgets/mf_dialog.dart';
import '../design/widgets/mf_document_card.dart';
import '../design/widgets/mf_empty_state.dart';
import '../design/widgets/mf_icon_button.dart';
import '../design/widgets/mf_mark.dart';
import '../design/widgets/mf_meta_row.dart';
import '../design/widgets/mf_page_thumb.dart';
import '../design/widgets/mf_privacy_mark.dart';
import '../design/widgets/mf_search_input.dart';
import '../design/widgets/mf_select.dart';
import '../design/widgets/mf_sheet.dart';
import '../design/widgets/mf_status_badge.dart';
import '../design/widgets/mf_tab_bar.dart';
import '../design/widgets/mf_text_field.dart';
import '../design/widgets/mf_toast.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.onToggleDark,
    required this.dark,
  });

  final VoidCallback onToggleDark;
  final bool dark;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _tab = 'archive';
  bool _chipSelected = true;
  String? _select = 'insurance';
  String _metaValue = 'Zilveren Kruis · Leusden';
  bool _corrected = false;

  Widget _section(String label, List<Widget> children) {
    final c = context.mf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(MfSpace.s6, MfSpace.s8, MfSpace.s6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: MfType.monoCaps.copyWith(color: c.text3),
          ),
          const SizedBox(height: MfSpace.s4),
          Wrap(spacing: MfSpace.s4, runSpacing: MfSpace.s4, children: children),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mf;
    return Scaffold(
      // Header clears the status bar / notch; MfTabBar pads the home
      // indicator itself, so the bottom inset stays with the bar.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MfAppHeader(
              connection: MfPrivacyTone.ok,
              actions: [
                MfIconButton(
                  label: widget.dark ? 'Switch to light' : 'Switch to dark',
                  onPressed: widget.onToggleDark,
                  child: MfIcon(MfGlyphs.gear, size: 18, color: c.text2),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  _section('Brand', [
                    const MfWordmark(),
                    MfMark(size: 40, color: c.accent),
                    MfPostmark(width: 150, color: c.text3),
                  ]),
                  _section('Buttons', [
                    const MfButton(
                      label: 'Photograph a letter',
                      onPressed: _noop,
                    ),
                    const MfButton(
                      label: 'Try again',
                      variant: MfButtonVariant.secondary,
                      onPressed: _noop,
                    ),
                    const MfButton(
                      label: 'Revoke',
                      variant: MfButtonVariant.destructive,
                      size: MfButtonSize.sm,
                      onPressed: _noop,
                    ),
                    const MfButton(
                      label: 'Ghost',
                      variant: MfButtonVariant.ghost,
                      onPressed: _noop,
                    ),
                    const MfButton(label: 'Disabled'),
                    MfButton(
                      label: 'Open the camera',
                      size: MfButtonSize.lg,
                      icon: const MfIcon(MfGlyphs.camera, size: 18),
                      onPressed: _noop,
                    ),
                    MfIconButton(
                      label: 'Filters',
                      onPressed: _noop,
                      child: MfIcon(MfGlyphs.filter, size: 18, color: c.text2),
                    ),
                  ]),
                  _section('Chips & badges', [
                    const MfChip(label: 'insurance'),
                    MfChip(
                      label: 'government',
                      selected: _chipSelected,
                      onTap: () =>
                          setState(() => _chipSelected = !_chipSelected),
                    ),
                    MfChip(label: 'polis 2026', onRemove: () {}),
                    const MfStatusBadge(status: MfStatus.queued),
                    const MfStatusBadge(
                      status: MfStatus.processing,
                      label: 'Reading page 1 of 2…',
                    ),
                    const MfStatusBadge(
                      status: MfStatus.done,
                      label: 'Filed · medical',
                    ),
                    const MfStatusBadge(
                      status: MfStatus.error,
                      label: "Couldn't read page 2",
                    ),
                    const MfStatusBadge(status: MfStatus.offline),
                  ]),
                  _section('Privacy marks', [
                    const MfPrivacyMark(),
                    const MfPrivacyMark(tone: MfPrivacyTone.ok),
                    const MfPrivacyMark(tone: MfPrivacyTone.warn),
                    const MfPrivacyMark(
                      label: 'uploads go to your server only',
                    ),
                  ]),
                  _section('Inputs', [
                    const SizedBox(width: 340, child: MfSearchInput()),
                    const SizedBox(
                      width: 200,
                      child: MfTextField(label: 'From', value: 'Jan 2026'),
                    ),
                    const SizedBox(
                      width: 200,
                      child: MfTextField(
                        label: 'Or share a token',
                        mono: true,
                        value: 'mfp_9k2c…f41a',
                      ),
                    ),
                    const SizedBox(
                      width: 200,
                      child: MfTextField(
                        label: 'Reference',
                        error: true,
                        message: 'Not a valid reference',
                        value: 'ZK//',
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: MfSelect(
                        label: 'Category',
                        placeholder: 'Any',
                        options: const [
                          'government',
                          'medical',
                          'insurance',
                          'telecom',
                        ],
                        value: _select,
                        onChanged: (v) => setState(() => _select = v),
                      ),
                    ),
                  ]),
                  _section('Page thumbs', [
                    const MfPageThumb(),
                    const MfPageThumb(pageNumber: 2, width: 52, height: 68),
                    MfPageThumb(width: 84, height: 110, onTap: () {}),
                  ]),
                  _section('Document cards', [
                    SizedBox(
                      width: 420,
                      child: MfDocumentCard(
                        title: 'Wijziging zorgverzekering 2026',
                        correspondent: 'Zilveren Kruis',
                        date: '12 Mar 2026',
                        category: 'insurance',
                        pages: 2,
                        onOpen: () {},
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: MfDocumentCard(
                        status: MfStatus.processing,
                        onOpen: () {},
                      ),
                    ),
                    SizedBox(
                      width: 230,
                      child: MfDocumentCard(
                        density: MfCardDensity.grid,
                        title: 'Jaaropgave 2025',
                        correspondent: 'Belastingdienst',
                        date: '28 Jan 2026',
                        category: 'government',
                        onOpen: () {},
                      ),
                    ),
                  ]),
                  _section('Meta rows (inline correction)', [
                    Container(
                      width: 480,
                      decoration: BoxDecoration(
                        color: c.surfaceCard,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(MfRadius.lg),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          MfMetaRow(
                            label: 'correspondent',
                            value: _metaValue,
                            corrected: _corrected,
                            onSave: (v) => setState(() {
                              _metaValue = v;
                              _corrected = true;
                            }),
                          ),
                          const MfMetaRow(
                            label: 'document date',
                            value: '12 Mar 2026',
                            mono: true,
                          ),
                          const MfMetaRow(
                            label: 'category',
                            editable: false,
                            child: MfChip(label: 'insurance'),
                          ),
                          const MfMetaRow(
                            label: 'reference',
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _section('Empty states', [
                    SizedBox(
                      width: 420,
                      child: MfEmptyState(
                        title: 'Nothing filed yet',
                        body: 'Your first letter is one photo away.',
                        action: MfButton(
                          label: 'Photograph a letter',
                          size: MfButtonSize.lg,
                          icon: const MfIcon(MfGlyphs.camera, size: 18),
                          onPressed: _noop,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: MfEmptyState(
                        title: "Can't reach your home server",
                        icon: MfIcon(MfGlyphs.wifiOff, size: 44, color: c.warn),
                        body:
                            "You're away from your home network. Your archive lives only on your own server — connect to the VPN to browse it.",
                        action: const MfButton(
                          label: 'Try again',
                          variant: MfButtonVariant.secondary,
                          onPressed: _noop,
                        ),
                      ),
                    ),
                  ]),
                  _section('Overlays', [
                    MfButton(
                      label: 'Show dialog',
                      variant: MfButtonVariant.secondary,
                      onPressed: () => showMfDialog<void>(
                        context,
                        title: 'Remove this page?',
                        body: const Text(
                          'The page is removed from this letter before upload. Nothing has left this device.',
                        ),
                        actions: [
                          MfButton(
                            label: 'Cancel',
                            variant: MfButtonVariant.ghost,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          MfButton(
                            label: 'Remove page',
                            variant: MfButtonVariant.destructive,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    MfButton(
                      label: 'Show sheet',
                      variant: MfButtonVariant.secondary,
                      onPressed: () => showMfSheet<void>(
                        context,
                        title: 'Filters',
                        builder: (_) => const Padding(
                          padding: EdgeInsets.only(bottom: MfSpace.s6),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              MfChip(label: 'All', selected: true),
                              MfChip(label: 'government'),
                              MfChip(label: 'medical'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    MfButton(
                      label: 'Show toast',
                      variant: MfButtonVariant.secondary,
                      onPressed: () => showMfToast(context, 'Saved.'),
                    ),
                  ]),
                  const SizedBox(height: MfSpace.s8),
                ],
              ),
            ),
            MfTabBar(active: _tab, onSelect: (id) => setState(() => _tab = id)),
          ],
        ),
      ),
    );
  }
}

void _noop() {}
