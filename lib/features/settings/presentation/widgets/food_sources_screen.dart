import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_const.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_food_catalogue_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/export_import_error_text.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings → Food databases: lets the user pick which food databases the
/// search screens draw from. State is persisted on
/// [ConfigEntity.foodSourceToggles]; a source not present in the map
/// defaults to enabled, so users who never visit this screen search every
/// database. Open Food Facts powers the product and barcode search and is
/// shown as a fixed, always-on entry.
///
/// Below the switches sits the catalogue-file import: a newer drop of a
/// bundled source (today only INDB ships one) as a JSON file, validated
/// against the same envelope the app bundles and replacing it for search
/// until removed again.
class FoodSourcesScreen extends StatefulWidget {
  const FoodSourcesScreen({super.key});

  @override
  State<FoodSourcesScreen> createState() => _FoodSourcesScreenState();
}

class _FoodSourcesScreenState extends State<FoodSourcesScreen> {
  Map<String, bool> _toggles = <String, bool>{};
  bool _loading = true;

  /// Recipe count of the stored imported catalogue, or null when search is
  /// running on the bundled asset alone.
  int? _importedCount;
  bool _importingCatalogue = false;

  @override
  void initState() {
    super.initState();
    _loadToggles();
  }

  Future<void> _loadToggles() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    final importedCount = await locator<ImportFoodCatalogueUsecase>()
        .importedItemCount();
    if (!mounted) return;
    setState(() {
      _toggles = Map<String, bool>.from(config.foodSourceToggles);
      _importedCount = importedCount;
      _loading = false;
    });
  }

  Future<void> _toggle(String sourceCode, bool enabled) async {
    setState(() => _toggles[sourceCode] = enabled);
    await locator<AddConfigUsecase>().setConfigFoodSourceToggles(_toggles);
  }

  /// Picks and validates a catalogue file, stores it, and reports what
  /// happened. A cancelled picker is silent by contract; a rejected or
  /// unwritable file gets the same error text the Settings import dialog
  /// uses, so the two flows speak with one voice.
  Future<void> _importCatalogue() async {
    if (_importingCatalogue) return;
    setState(() => _importingCatalogue = true);
    final result = await locator<ImportFoodCatalogueUsecase>()
        .importFromPickedFile();
    if (!mounted) return;
    setState(() => _importingCatalogue = false);
    if (result == null) return;
    if (result.isSuccess) {
      setState(() => _importedCount = result.itemCount);
      _showSnack(
        S.of(context).foodSourcesImportCatalogueSuccess(result.itemCount!),
      );
    } else {
      _showSnack(exportImportErrorText(S.of(context), result.failureReason!));
    }
  }

  Future<void> _removeImportedCatalogue() async {
    await locator<ImportFoodCatalogueUsecase>().removeImportedCatalogue();
    if (!mounted) return;
    setState(() => _importedCount = null);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the database's public website in the in-app browser (Custom
  /// Tabs / SFSafariViewController) so the user stays inside the app.
  Future<void> _openSourceInfo(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  }

  Widget _infoButton(String url) => IconButton(
        icon: const Icon(Icons.info_outline_rounded),
        onPressed: () => _openSourceInfo(url),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsFoodSourcesLabel)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    s.foodSourcesHelpText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SwitchListTile(
                  secondary: _infoButton(OFFConst.offWebsiteUrl),
                  title: const Text(OFFConst.offSourceName),
                  subtitle: Text(s.foodSourcesAlwaysEnabledLabel),
                  value: true,
                  onChanged: null,
                ),
                for (final sourceCode in SPConst.settingsSelectableFoodSources)
                  SwitchListTile(
                    secondary: _infoButton(
                      SPConst.foodSourceWebsites[sourceCode]!,
                    ),
                    title: Text(
                      SPConst.foodSourceDisplayNames[sourceCode] ?? sourceCode,
                    ),
                    // CC BY 4.0 attribution for the bundled INDB catalogue,
                    // the licence's visible-credit requirement.
                    subtitle: sourceCode == SPConst.indbSourceCode
                        ? Text(s.foodSourcesIndbSubtitle)
                        : null,
                    value: _toggles[sourceCode] ?? true,
                    onChanged: (value) => _toggle(sourceCode, value),
                  ),
                const Divider(),
                Semantics(
                  identifier: 'food-sources-import-catalogue',
                  child: ListTile(
                    leading: _importingCatalogue
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    title: Text(s.foodSourcesImportCatalogueLabel),
                    subtitle: Text(
                      _importedCount != null
                          ? s.foodSourcesImportedCatalogueCount(_importedCount!)
                          : s.foodSourcesImportCatalogueHint,
                    ),
                    onTap: _importingCatalogue ? null : _importCatalogue,
                  ),
                ),
                if (_importedCount != null)
                  Semantics(
                    identifier: 'food-sources-remove-catalogue',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(s.foodSourcesImportCatalogueRemove),
                      onTap: _removeImportedCatalogue,
                    ),
                  ),
              ],
            ),
    );
  }
}
