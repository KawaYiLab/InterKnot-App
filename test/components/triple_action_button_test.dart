import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/components/triple_action_button.dart';

void main() {
  testWidgets('short tap triggers onLike', (tester) async {
    var likeCalled = false;
    var tripleCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripleActionButton(
            liked: false,
            likesCount: 6,
            canTriple: true,
            onLike: () => likeCalled = true,
            onTriple: () => tripleCalled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();

    expect(likeCalled, isTrue);
    expect(tripleCalled, isFalse);
  });

  testWidgets('long press triggers onTriple', (tester) async {
    var likeCalled = false;
    var tripleCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripleActionButton(
            liked: false,
            likesCount: 6,
            canTriple: true,
            onLike: () => likeCalled = true,
            onTriple: () => tripleCalled = true,
          ),
        ),
      ),
    );

    await tester.longPress(find.byIcon(Icons.thumb_up_outlined));
    await tester.pumpAndSettle();

    expect(tripleCalled, isTrue);
    expect(likeCalled, isFalse);
  });
}
