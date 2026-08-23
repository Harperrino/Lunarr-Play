import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_library_sidebar.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

import 'jellyfin_test_helpers.dart';

const _libraries = [
  JellyfinLibrary(id: 'movies', name: 'Movies', collectionType: 'movies'),
  JellyfinLibrary(id: 'shows', name: 'TV Shows', collectionType: 'tvshows'),
];

void main() {
  testWidgets('sidebar exposes overview first and selects server libraries', (
    tester,
  ) async {
    var overviewSelected = false;
    JellyfinLibrary? selectedLibrary;

    await tester.pumpWidget(
      jellyfinTestHost(
        SizedBox(
          height: 480,
          child: JellyfinLibrarySidebar(
            libraries: _libraries,
            selectedLibraryId: 'movies',
            onOverviewSelected: () => overviewSelected = true,
            onLibrarySelected: (library) => selectedLibrary = library,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('TV Shows'), findsOneWidget);
    expect(
      tester
          .widget<M3NavigationItem>(
            find.byKey(const ValueKey('jellyfin-library-movies')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('jellyfin-library-shows')));
    expect(selectedLibrary, _libraries[1]);
    await tester.tap(find.byKey(const ValueKey('jellyfin-library-overview')));
    expect(overviewSelected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow picker opens an accessible M3 menu', (tester) async {
    JellyfinLibrary? selectedLibrary;

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinLibraryPicker(
          libraries: _libraries,
          selectedLibraryId: null,
          onOverviewSelected: () {},
          onLibrarySelected: (library) => selectedLibrary = library,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('jellyfin-library-picker-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('jellyfin-library-menu-shows')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('jellyfin-library-menu-shows')));
    await tester.pump();
    expect(selectedLibrary, _libraries[1]);
    expect(tester.takeException(), isNull);
  });
}
