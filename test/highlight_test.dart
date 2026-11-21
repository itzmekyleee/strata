import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
// ignore: implementation_imports — stringToColor is not part of the public API.
import 'package:flutter_quill/src/common/utils/color.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor's highlight toggle applies and removes quill's `background`
/// attribute over the selection; verify the value Strata stores round-trips
/// through a delta the same way the editor applies it.
void main() {
  QuillController controller() => QuillController(
    document: Document()..insert(0, 'hello world'),
    selection: const TextSelection(baseOffset: 0, extentOffset: 5),
  );

  test('highlight value parses as translucent amber', () {
    expect(stringToColor('#4DDEA133'), const Color(0x4DDEA133));
  });

  test('applying the highlight adds a background attribute', () {
    final c = controller();
    c.formatSelection(const BackgroundAttribute('#4DDEA133'));

    final attrs = c.document.toDelta().first.attributes;
    expect(attrs?['background'], '#4DDEA133');
  });

  test('removing the highlight strips the background attribute', () {
    final c = controller();
    c.formatSelection(const BackgroundAttribute('#4DDEA133'));
    c.formatSelection(Attribute.clone(Attribute.background, null));

    final attrs = c.document.toDelta().first.attributes;
    expect(attrs, isNot(contains('background')));
  });
}
