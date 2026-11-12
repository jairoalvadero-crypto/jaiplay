import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jaiplay/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recent searches persist, deduplicate, and merge from the cloud',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();

    store.addRecentSearch(' Rosalía ');
    store.addRecentSearch('Motomami');
    store.addRecentSearch('rosalía');

    expect(store.recentSearches, ['rosalía', 'Motomami']);

    final restored = Store();
    await restored.load();
    expect(restored.recentSearches, ['rosalía', 'Motomami']);

    restored.applyRemote({
      'favs': [],
      'recents': [],
      'artists': [],
    });
    expect(restored.recentSearches, ['rosalía', 'Motomami']);

    restored.mergeRemote({
      'recentSearches': ['Motomami', 'Bad Bunny'],
    });
    expect(restored.recentSearches, ['rosalía', 'Motomami', 'Bad Bunny']);

    restored.clearRecentSearches();
    final cleared = Store();
    await cleared.load();
    expect(cleared.recentSearches, isEmpty);
  });
}
