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
days since the Unix epoch. Open tasks keep their insertion order; a checked one
strikes through where it stands, then sinks to the head of the completed group.
That ordering lives in `compareTodos` and nowhere else.

Each task is a bordered card showing a single line, ellipsised when it runs
long, and carries no checkbox. Arabic and Hebrew tasks lay themselves out right
to left, decided by the first strong letter so a leading digit or emoji does not
throw it off. Double tapping one opens a
sheet with done, edit and delete. Swiping uncovers the same buttons, right for
done and edit, left for delete, and nothing happens until one is tapped. Open
tasks have a grip on the right for dragging them into a new order, which is
written back as positions. Writing a task always happens on its own full screen,
never inline.

A task can repeat daily, weekly on any set of weekdays, or monthly. Repeats are
stored as rules rather than as a row per day, so any day past or future can be
opened at once and nothing is written until you act on an occurrence. Deleting
one asks whether you mean this day, this day and earlier, this day and later, or
the whole thing.

```
lib/
  core/     dates, labels, theme
  data/     the Todo record, the store interface, the SQLite store
  state/    Riverpod providers and the two notifiers
  ui/       screens, plus the brand kit every screen is built from
  ui/branded/  BrandedText, BrandedAppBar, BrandedActionGrid and the rest
```

## Tests

```
fvm flutter test
```

Widget tests drive the real interface against the in-memory store: the editor
screen, the action sheet, ordering, day navigation, the month grid,
swipe-to-delete, and the iPad width cap. A separate test fails the build if a
screen reaches for a raw Material widget instead of a Branded one.
