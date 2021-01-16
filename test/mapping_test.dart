// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osmp_project/main.dart';
import 'package:osmp_project/MappingSupport.dart';
import 'package:latlong/latlong.dart';

void main() {
  group('Decoder', ()
  {
    test('Decoding a polyline', ()
    {
      // final decoder = Decoder();
      // decoder.decodePolyline2('`~oia@');
      // decoder.decodePolyline2('u{~vFvyys@fS]');
      //
      // decoder.decodePolyline2('_p~iF');
      // decoder.decodePolyline2('~ps|U');
      // expect(decoder.decode('_p~iF'), 38.5);
      // expect(decoder.decode('~ps|U'), -120.2);
      //
      // expect(decoder.decode('_ulL'), moreOrLessEquals(40.7 - 38.5));
      // expect(decoder.decode('nnqC'), moreOrLessEquals(-120.95 - (-120.2)));
      //
      // final decoded = decoder.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      // final expected = [
      //   new LatLng(38.5, -120.2),
      //   new LatLng(40.7, -120.95),
      //   new LatLng(43.252, -126.453)
      // ];
      // var index = 0;
      // decoded.forEach((element) {
      //   expect(element.latitude, moreOrLessEquals(expected[index].latitude));
      //   expect(element.longitude, moreOrLessEquals(expected[index].longitude));
      //   index += 1;
      // });

      // final encodedPoly = 'sx{rF|djaS@B@@???@?@?L?H?N?L?H?F?F?H?H?F?L?R?J?\\?F?D?B?T?J?B?H?H?L?H?L?N?H?L?L?H?@?D?H?L?J?J?H?L?F?H?R?J?N?L?F?H?L?H?L?H?H?D?L?H?D?D@P?D?B?B?@?@?@@BBD@B@B@D';
      //
      // decoder.decodePolyline2(encodedPoly);

      // final polyLine = decoder.decodePolyline(encodedPoly);
      // polyLine.forEach((element) {
      //   debugPrint(element.toString());
      // });
    });
    // testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    //   // Build our app and trigger a frame.
    //   await tester.pumpWidget(MyApp());
    //
    //   // Verify that our counter starts at 0.
    //   expect(find.text('0'), findsOneWidget);
    //   expect(find.text('1'), findsNothing);
    //
    //   // Tap the '+' icon and trigger a frame.
    //   await tester.tap(find.byIcon(Icons.add));
    //   await tester.pump();
    //
    //   // Verify that our counter has incremented.
    //   expect(find.text('0'), findsNothing);
    //   expect(find.text('1'), findsOneWidget);
    // });
  });
}
