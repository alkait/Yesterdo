import 'package:flutter/material.dart';

import 'branded/branded.dart';
import 'widgets/date_header.dart';
import 'widgets/todo_composer.dart';
import 'widgets/todo_list_view.dart';

/// The whole app: a day, its tasks, and a place to add one.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const BrandedScaffold(
    children: [
      DateHeader(),
      Expanded(child: TodoListView()),
      TodoComposer(),
    ],
  );
}
