import 'dart:convert';

import 'package:flutter/material.dart';

/// Built-in note templates shipped with the app.
abstract final class BuiltinTemplates {
  static List<BuiltinTemplate> all = [
    BuiltinTemplate(
      name: 'Meeting notes',
      icon: Icons.groups_2_outlined,
      deltaJson: _encode(_meetingOps()),
    ),
    BuiltinTemplate(
      name: 'Daily journal',
      icon: Icons.auto_stories_outlined,
      deltaJson: _encode(_journalOps()),
    ),
    BuiltinTemplate(
      name: 'Reading list',
      icon: Icons.menu_book_outlined,
      deltaJson: _encode(_readingOps()),
    ),
  ];

  static Map<String, dynamic> _op(
    String insert, [
    Map<String, dynamic>? attrs,
  ]) => {'insert': insert, 'attributes': ?attrs};

  static List<Map<String, dynamic>> _header(String text) => [
    _op(text),
    _op('\n', const {'header': 3}),
  ];

  static List<Map<String, dynamic>> _bullet(String text) => [
    _op(text),
    _op('\n', const {'list': 'bullet'}),
  ];

  static String _encode(List<Map<String, dynamic>> ops) => jsonEncode(ops);

  static List<Map<String, dynamic>> _meetingOps() => [
    ..._header('Attendees'),
    _op('Add everyone who was there…\n'),
    _op('\n'),
    ..._header('Agenda'),
    ..._bullet('Topic one'),
    ..._bullet('Topic two'),
    _op('\n'),
    ..._header('Decisions'),
    _op('Summarize what was decided…\n'),
    _op('\n'),
    ..._header('Action items'),
    ..._bullet('Owner — task'),
  ];

  static List<Map<String, dynamic>> _journalOps() => [
    ..._header('Highlights'),
    ..._bullet('The best part of today…'),
    _op('\n'),
    ..._header('Challenges'),
    _op('What was hard, what you learned…\n'),
    _op('\n'),
    ..._header('Grateful for'),
    _op('Three things…\n'),
    _op('\n'),
    ..._header('Tomorrow'),
    ..._bullet('One thing to move forward'),
  ];

  static List<Map<String, dynamic>> _readingOps() {
    const cells = <String>[
      'Title', 'Author', 'Status', 'Notes', //
      '', '', '', '', //
      '', '', '', '', //
      '', '', '', '',
    ];
    final table = jsonEncode({'cols': 4, 'rows': 4, 'cells': cells});
    return [
      ..._header('Reading list'),
      {
        'insert': {'table': table},
      },
      _op('\n'),
      _op('Add rows via the Table button in the toolbar.\n'),
    ];
  }
}

class BuiltinTemplate {
  const BuiltinTemplate({
    required this.name,
    required this.icon,
    required this.deltaJson,
  });

  final String name;
  final IconData icon;
  final String deltaJson;
}
