# RemindMe

A day-at-a-time todo list for iPhone and iPad. Offline, local, no account, no sync.

## Running it

The Flutter version is pinned with [FVM](https://fvm.app):

```
fvm install
fvm flutter pub get
fvm flutter run
```

iOS is the only enabled platform.

## Shape of the code

State is Riverpod, and only Riverpod. `lib/state/providers.dart` is the single
place providers are declared:

- `selectedDayProvider` holds the day the interface is looking at.
- `todosProvider` rebuilds that day's list whenever the day changes.
- `todoStoreProvider` is bound to SQLite in `main`, and to an in-memory double
  in tests.

Storage is one SQLite table keyed by day, where a day is the integer count of
days since the Unix epoch. Open tasks keep their insertion order; checking one
strikes it where it stands, then sinks it below the rest. That ordering lives
in `compareTodos` and nowhere else.

```
lib/
  core/     dates, labels, theme, layout constants
  data/     the Todo record, the store interface, the SQLite store
  state/    Riverpod providers and the two notifiers
  ui/       one page and its widgets
```

## Tests

```
fvm flutter test
```

Widget tests drive the real interface against the in-memory store: adding,
checking, unchecking, day navigation, the month grid, swipe-to-delete, and the
iPad width cap.
