import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/zar_domain_models.dart';

/// The small set of safe, non-sensitive choices remembered by Quick Entry.
/// Amounts, prices, people and notes are intentionally never persisted here.
class QuickEntryPreferences {
  const QuickEntryPreferences({
    this.weightUnit = ZarGoldUnit.gram,
    this.priceUnit = ZarGoldUnit.gram,
    this.goldPurity = '750',
    this.currencyCode = 'USD',
    this.coinTypeId,
  });

  final ZarGoldUnit weightUnit;
  final ZarGoldUnit priceUnit;
  final String goldPurity;
  final String currencyCode;
  final String? coinTypeId;
}

abstract interface class QuickEntryPreferenceStore {
  Future<QuickEntryPreferences> load();
  Future<void> save(QuickEntryPreferences preferences);
}

/// Deterministic store for widget tests and embedded/demo hosts.
class InMemoryQuickEntryPreferenceStore implements QuickEntryPreferenceStore {
  InMemoryQuickEntryPreferenceStore([
    this._value = const QuickEntryPreferences(),
  ]);

  QuickEntryPreferences _value;

  @override
  Future<QuickEntryPreferences> load() async => _value;

  @override
  Future<void> save(QuickEntryPreferences preferences) async {
    _value = preferences;
  }
}

class SharedPreferencesQuickEntryPreferenceStore
    implements QuickEntryPreferenceStore {
  SharedPreferencesQuickEntryPreferenceStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs;

  final SharedPreferencesAsync? _prefs;

  static const _weightKey = 'zar.quick_entry.weight_unit';
  static const _priceKey = 'zar.quick_entry.price_unit';
  static const _purityKey = 'zar.quick_entry.gold_purity';
  static const _currencyKey = 'zar.quick_entry.currency';
  static const _coinKey = 'zar.quick_entry.coin_type';

  @override
  Future<QuickEntryPreferences> load() async {
    final prefs = _prefs ?? SharedPreferencesAsync();
    final weight = await prefs.getString(_weightKey);
    final price = await prefs.getString(_priceKey);
    final purity = await prefs.getString(_purityKey);
    final currency = await prefs.getString(_currencyKey);
    final coin = await prefs.getString(_coinKey);
    return QuickEntryPreferences(
      weightUnit: _goldUnit(weight) ?? ZarGoldUnit.gram,
      priceUnit: _goldUnit(price) ?? ZarGoldUnit.gram,
      goldPurity: purity?.trim().isNotEmpty == true ? purity! : '750',
      currencyCode: currency?.trim().isNotEmpty == true ? currency! : 'USD',
      coinTypeId: coin,
    );
  }

  @override
  Future<void> save(QuickEntryPreferences preferences) async {
    final prefs = _prefs ?? SharedPreferencesAsync();
    await prefs.setString(_weightKey, preferences.weightUnit.name);
    await prefs.setString(_priceKey, preferences.priceUnit.name);
    await prefs.setString(_purityKey, preferences.goldPurity);
    await prefs.setString(_currencyKey, preferences.currencyCode);
    if (preferences.coinTypeId == null) {
      await prefs.remove(_coinKey);
    } else {
      await prefs.setString(_coinKey, preferences.coinTypeId!);
    }
  }

  ZarGoldUnit? _goldUnit(String? value) {
    if (value == ZarGoldUnit.gram.name) return ZarGoldUnit.gram;
    if (value == ZarGoldUnit.mesghal.name) return ZarGoldUnit.mesghal;
    return null;
  }
}
