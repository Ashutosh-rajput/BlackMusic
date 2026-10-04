import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/presentation/bloc/player/player_bloc.dart';
import 'package:vinyl/presentation/bloc/player/player_event.dart';
import 'package:vinyl/presentation/bloc/player/player_state.dart';
import 'package:vinyl/presentation/widgets/swipe_to_skip.dart';

/// Records the events the widget sends, without any audio behind it.
class RecordingPlayerBloc extends Cubit<PlayerState> implements PlayerBloc {
  RecordingPlayerBloc() : super(const PlayerInitial());

  final List<PlayerEvent> events = [];

  @override
  void add(PlayerEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late RecordingPlayerBloc bloc;
  int taps = 0;

  Future<void> pumpBar(WidgetTester tester) async {
    taps = 0;
    bloc = RecordingPlayerBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PlayerBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Center(
              child: SwipeToSkip(
                maxTravel: 90,
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox(
                    key: Key('bar'),
                    width: 300,
                    height: 60,
                    child: ColoredBox(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final bar = find.byKey(const Key('bar'));

  // A real finger sends many small moves; one big jump only crosses the
  // touch-slop threshold and reports no travel.
  Future<void> moveInSteps(WidgetTester tester, TestGesture gesture, double totalDx) async {
    final steps = (totalDx.abs() / 5).ceil();
    for (var i = 0; i < steps; i++) {
      // Real timestamps (8ms per step): the tester stamps events with time
      // zero by default, which would make every gesture look motionless to the
      // velocity tracker.
      await gesture.moveBy(Offset(totalDx.sign * 5, 0), timeStamp: Duration(milliseconds: 8 * (i + 1)));
      await tester.pump(const Duration(milliseconds: 8));
    }
  }

  testWidgets('swipe left asks for the next song', (tester) async {
    await pumpBar(tester);
    await tester.drag(bar, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(bloc.events, hasLength(1));
    expect(bloc.events.single, isA<NextSongEvent>());
    expect((bloc.events.single as NextSongEvent).isManualSkip, isTrue);
  });

  testWidgets('swipe right asks for the previous song', (tester) async {
    await pumpBar(tester);
    await tester.drag(bar, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(bloc.events, hasLength(1));
    expect(bloc.events.single, isA<PreviousSongEvent>());
  });

  testWidgets('a quick flick counts even when the drag is short', (tester) async {
    await pumpBar(tester);
    // 45px (under the 60px swipe distance) in ~70ms is ~640px/s, above the
    // 350px/s flick speed.
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await moveInSteps(tester, gesture, -45);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(bloc.events.single, isA<NextSongEvent>());
  });

  testWidgets('a small slow drag does nothing', (tester) async {
    await pumpBar(tester);
    await tester.drag(bar, const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(bloc.events, isEmpty);
  });

  testWidgets('the bar follows the finger and springs back to rest', (tester) async {
    await pumpBar(tester);
    final start = tester.getTopLeft(bar).dx;
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await moveInSteps(tester, gesture, -45);
    expect(tester.getTopLeft(bar).dx, lessThan(start - 20));
    await moveInSteps(tester, gesture, 20); // finish well under the swipe distance
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(bar).dx, closeTo(start, 0.5));
    expect(bloc.events, isEmpty);
  });

  testWidgets('the bar never travels further than maxTravel', (tester) async {
    await pumpBar(tester);
    final start = tester.getTopLeft(bar).dx;
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await moveInSteps(tester, gesture, -200);
    expect(start - tester.getTopLeft(bar).dx, lessThanOrEqualTo(90.5));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a tap still reaches the child (opens the player)', (tester) async {
    await pumpBar(tester);
    await tester.tap(bar);
    expect(taps, 1);
    expect(bloc.events, isEmpty);
  });
}
