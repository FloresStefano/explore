import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weekend_break/data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('switching a country off hides its offers, scope changes, all/none work', () async {
    await App.prefs.load();
    final before = App.prefs.scope;
    App.prefs.toggleCountry('ES');
    expect(App.prefs.excludedCountries, {'es'});
    expect(App.prefs.scope, isNot(before));
    App.prefs.toggleCountry('es');
    expect(App.prefs.excludedCountries, isEmpty);
    App.prefs.setAllCountries(false, ['es', 'it']);
    expect(App.prefs.excludedCountries, {'es', 'it'});
    App.prefs.setAllCountries(true, ['es', 'it']);
    expect(App.prefs.excludedCountries, isEmpty);
    expect((await SharedPreferences.getInstance()).getStringList('USR-05'), isEmpty);
  });
}
