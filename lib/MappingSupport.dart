import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tappable_polyline/flutter_map_tappable_polyline.dart';

import 'package:osmp_project/trail_progress_list_widget.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/markTrailComplete.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// ----
Widget displayMap(BuildContext context, TrailSummary trail, SettingsOptions settingsOptions) {
  MapData inputMapData = MapData();
  inputMapData.mapName = Text(trail.name);
  inputMapData.percentComplete = trail.percentDone;

  // ----
  Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/singleTrail'),
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(trail.name),
                  Text((trail.percentDone * 100).toStringAsFixed(2) + '%',
                      style: TextStyle(
                        fontSize: 12.0,
                      )),
                  LinearProgressIndicator(
                    value: trail.percentDone,
                    backgroundColor: inputMapData.remainingSegColor,
                    valueColor: AlwaysStoppedAnimation<Color>(inputMapData.completedSegColor),
                    minHeight: 3,
                  )
                ],
              ),
              actions: <Widget>[
                //if (trail.percentDone < 0.995)
                  TextButton(
                    onPressed: () {
                      // confirm that this is what the user wants to do
                      // and then mark the trail as completed
                      return showCompleteTrailManuallyDialog(context, trail.name);
                    },
                    child: Column(
                      children: [
                        Text('Mark this', style: TextStyle(color: Colors.yellow)),
                        Text('trail complete', style: TextStyle(color: Colors.yellow)),
                      ],
                      mainAxisAlignment: MainAxisAlignment.center,
                    ),
                  )
              ],
            ),
            body: _LoadDisplayMapData(trail, inputMapData, settingsOptions),
          );
        },
      ));

  return _NoDataScreen();
}

// ----
Widget displayMapSummary(BuildContext context, MapData inputMapSummaryData, SettingsOptions settingsOptions) {
  double percentDone = inputMapSummaryData.percentComplete;

  Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/summaryMap'),
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text("Overall completion"),
                  Text((percentDone * 100).toStringAsFixed(2) + '%',
                      style: TextStyle(
                        fontSize: 12.0,
                      )),
                  LinearProgressIndicator(
                    value: percentDone,
                    backgroundColor: inputMapSummaryData.remainingSegColor,
                    valueColor: AlwaysStoppedAnimation<Color>(inputMapSummaryData.completedSegColor),
                    minHeight: 3,
                  )
                ],
              ),
            ),
            body: _LoadDisplayMapSummaryData(inputMapSummaryData, settingsOptions),
          );
        },
      ));

  return _NoDataScreen();
}

//----
class _LoadDisplayMapSummaryData extends StatelessWidget {
  _LoadDisplayMapSummaryData(this.inputMapSummaryData, this.settingsOptions);
  final MapData inputMapSummaryData;
  final SettingsOptions settingsOptions;

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();

    Stream theStream =
        FirebaseFirestore.instance.collection('athletes').doc(firebaseUser.email).collection("trailStats").snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: theStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();

        // for each trail add all the completed and remaining segments to an overallTrailSummary
        TrailSummary overallTrailSummary = TrailSummary();
        snapshot.data.docs.forEach((DocumentSnapshot document) {
          TrailSummary theSummaryForTheTrail = TrailSummary.fromSnapshot(document);
          overallTrailSummary.completedSegs.addAll(theSummaryForTheTrail.completedSegs);
          overallTrailSummary.remainingSegs.addAll(theSummaryForTheTrail.remainingSegs);
        });

        return _LoadDisplayMapData(overallTrailSummary, inputMapSummaryData, settingsOptions);
      },
    );
  }
}

// ----
Future<String> readSegmentsStringFromJson() async {
  String jsonString;
  try {
    jsonString = await rootBundle.loadString('assets/mapData/encoded-segments.json');
  } catch (e) {
    debugPrint("Couldn't read encoded segments asset file");
  }
  return jsonString;
}

//----
class _LoadDisplayMapData extends StatelessWidget {
  _LoadDisplayMapData(this.trail, this.inputMapData, this.settingsOptions);
  final TrailSummary trail;
  final MapData inputMapData;
  final SettingsOptions settingsOptions;

  @override
  Widget build(BuildContext context) {
    if (inputMapData.useJsonForSegments) {
      // --
      // Pull the trail segment data out of assets/MapData/encoded-segments.json
      List<SegmentSummary> segmentList = [];
      return FutureBuilder<String>(
        future: readSegmentsStringFromJson(),
        builder: (BuildContext context, AsyncSnapshot<String> jsonString) {
          if (jsonString.hasData) {
            Map<String, dynamic> jsonMapObject = jsonDecode(jsonString.data);
            jsonMapObject.forEach(
              (key, trailSeg) {
                SegmentSummary segment = SegmentSummary.fromMap(trailSeg);

                if (inputMapData.isMapSummary) {
                  // get all segments
                  segmentList.add(segment);
                } else if (segment.name == trail.name) {
                  // get only the segments for the given trail name
                  segmentList.add(segment);
                }
              },
            );
            return _populateMapData(context, trail, inputMapData, settingsOptions, segmentList);
          } else {
            Center(
              child: SizedBox(
                child: CircularProgressIndicator(),
                width: 40,
                height: 40,
              ),
            );
          }

          return Center(
            child: SizedBox(
              child: CircularProgressIndicator(),
              width: 40,
              height: 40,
            ),
          );
        },
      );
    } else {
      // --
      // Pull the trail segment data out of Firestore
      Stream theStream;
      if (inputMapData.isMapSummary) {
        // get all the segments
        theStream = FirebaseFirestore.instance.collection('segments').snapshots();
      } else {
        // get only the segments for the given trail name
        theStream = FirebaseFirestore.instance.collection('segments').where('name', isEqualTo: trail.name).snapshots();
      }
      return StreamBuilder<QuerySnapshot>(
        stream: theStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return LinearProgressIndicator();
          {
            // pull the list of segments out of the QuerySnapshot
            List<SegmentSummary> segmentList = [];
            snapshot.data.docs.forEach(
              (DocumentSnapshot document) {
                SegmentSummary segment = SegmentSummary.fromSnapshot(document);
                segmentList.add(segment);
              },
            );
            return _populateMapData(context, trail, inputMapData, settingsOptions, segmentList);
          }
        },
      );
    }
  }
}

// ----
Widget _populateMapData(BuildContext context, TrailSummary trail, MapData inputMapData, SettingsOptions settingsOptions,
    List<SegmentSummary> segmentList) {
  // build data for the trail map
  inputMapData.completedSegs = [];
  inputMapData.remainingSegs = [];

  // go through the list of segments for this trail or set of trails
  segmentList.forEach((SegmentSummary segment) {
    String segmentNameId = segment.segmentNameId;
    String encodedLocations = segment.encodedLocations;
    segment.latLong = _buildPolyLineForMap(encodedLocations);


    // is this segment completed or remaining
    if (List.castFrom(trail.completedSegs).contains(segmentNameId))
      inputMapData.completedSegs.add(segment);
    else if (List.castFrom(trail.remainingSegs).contains(segmentNameId))
      inputMapData.remainingSegs.add(segment);
    else {
      inputMapData.remainingSegs.add(segment);
      print('No segment data <<>> ${segment.name} ${segment.segmentNameId} <> considered not completed');

      //print(' percent done ${trail.percentDone} ${inputMapData.percentComplete}');
    }
  });

  return _CreateFlutterMap(inputMapData, settingsOptions);
}

// ----
Future<void> _mapInfoAlert(BuildContext context, String segmentNameID, Map<String, String> theTrailNamesMap,
    Map<String, double> theTrailLengthMap) async {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      String trailName = theTrailNamesMap[segmentNameID];
      return Padding(
        padding: EdgeInsets.only(bottom: 450.0),
        child: Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            SizedBox(
              height: 15,
            ),
            Text(
              trailName,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(
              height: 2,
            ),
            Text(
              "Trail Length: " + theTrailLengthMap[trailName].toStringAsFixed(2) + " miles",
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(
              height: 2,
            ),
            Text(
              "SegmentID: " + segmentNameID,
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(
              height: 15,
            ),
          ]),
        ),
      );
    },
  );
}

// ----
class _CreateFlutterMap extends StatefulWidget {
  _CreateFlutterMap(this.theMapData, this.settingsOptions);
  final MapData theMapData;
  final SettingsOptions settingsOptions;

  @override
  __CreateFlutterMapState createState() => __CreateFlutterMapState();
}

// ----
class __CreateFlutterMapState extends State<_CreateFlutterMap> {
  MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    // keep track of max/min lat long for all segments
    double maxLat = -double.maxFinite;
    double minLat = double.maxFinite;
    double maxLong = -double.maxFinite;
    double minLong = double.maxFinite;

    // trail or trail segment names
    List<Marker> theTrailNameMarkers = [];

    // map from segmentNameID to trail name
    Map theTrailNamesMap = Map<String, String>();

    // map from segmentNameID to segment length
    Map theTrailLengthMap = Map<String, double>();

    // completed segments in one color
    List<TaggedPolyline> theSegmentPolylines = [];
    widget.theMapData.completedSegs.forEach((SegmentSummary segment) {
      TaggedPolyline polyline = TaggedPolyline(
          points: segment.latLong, strokeWidth: 4.0, color: widget.theMapData.completedSegColor, tag: segment.segmentNameId);
      theSegmentPolylines.add(polyline);

      // segmentNameID to trail name
      String trailName = segment.name;
      theTrailNamesMap[segment.segmentNameId] = trailName;

      // trail name to trail total length (convert from meters to miles)
      if (theTrailLengthMap.isEmpty || (theTrailLengthMap.containsKey(trailName) == false))
        theTrailLengthMap[trailName] = (segment.length) / 1609.34;
      else
        theTrailLengthMap[trailName] = theTrailLengthMap[trailName] + (segment.length) / 1609.34;

      // keep track of max/min lat long for all segments
      if (segment.boundsMap['maxLatitude'] > maxLat) maxLat = segment.boundsMap['maxLatitude'];
      if (segment.boundsMap['maxLongitude'] > maxLong) maxLong = segment.boundsMap['maxLongitude'];
      if (segment.boundsMap['minLatitude'] < minLat) minLat = segment.boundsMap['minLatitude'];
      if (segment.boundsMap['minLongitude'] < minLong) minLong = segment.boundsMap['minLongitude'];

      // trail or trail segment names on the map (optionally)
      if (widget.settingsOptions.displayTrailNames || widget.settingsOptions.displaySegmentNames) {
        if (polyline.points.isNotEmpty) {
          // approx center of polyline
          // int pntID = ((polyline.points.length) / 2).toInt();
          int pntID = polyline.points.length ~/ 2;

          // the marker with the trail or segment name
          String markerString = segment.name;
          if (widget.settingsOptions.displaySegmentNames) markerString = segment.segmentNameId;

          Marker segNameMarker = Marker(
            width: 80.0,
            point: polyline.points[pntID],
            builder: (ctx) => Container(
              child: Text(markerString, style: TextStyle(fontSize: 12.0)),
            ),
          );

          theTrailNameMarkers.add(segNameMarker);
        }
      }
    });

    // remaining segments in another color
    widget.theMapData.remainingSegs.forEach((SegmentSummary segment) {
      TaggedPolyline polyline = TaggedPolyline(
          points: segment.latLong, strokeWidth: 4.0, color: widget.theMapData.remainingSegColor, tag: segment.segmentNameId);
      theSegmentPolylines.add(polyline);

      // segmentNameID to trail name
      String trailName = segment.name;
      theTrailNamesMap[segment.segmentNameId] = trailName;

      // trail name to trail total length (convert from meters to miles)
      if (theTrailLengthMap.isEmpty || (theTrailLengthMap.containsKey(trailName) == false))
        theTrailLengthMap[trailName] = (segment.length) / 1609.34;
      else
        theTrailLengthMap[trailName] = theTrailLengthMap[trailName] + (segment.length) / 1609.34;

      // keep track of max/min lat long for all segments
      if (segment.boundsMap['maxLatitude'] > maxLat) maxLat = segment.boundsMap['maxLatitude'];
      if (segment.boundsMap['maxLongitude'] > maxLong) maxLong = segment.boundsMap['maxLongitude'];
      if (segment.boundsMap['minLatitude'] < minLat) minLat = segment.boundsMap['minLatitude'];
      if (segment.boundsMap['minLongitude'] < minLong) minLong = segment.boundsMap['minLongitude'];

      // trail or trail segment names on the map (optionally)
      if (widget.settingsOptions.displayTrailNames || widget.settingsOptions.displaySegmentNames) {
        if (polyline.points.isNotEmpty) {
          // approx center of polyline
          // int pntID = ((polyline.points.length) / 2).toInt();
          int pntID = polyline.points.length ~/ 2;

          // the marker with the trail or segment name
          String markerString = segment.name;
          if (widget.settingsOptions.displaySegmentNames) markerString = segment.segmentNameId;

          Marker segNameMarker = Marker(
            width: 80.0,
            point: polyline.points[pntID],
            builder: (ctx) => Container(
              child: Text(markerString, style: TextStyle(fontSize: 12.0)),
            ),
          );

          theTrailNameMarkers.add(segNameMarker);
        }
      }
    });

    // set up map boundaries
    List<LatLng> mapBounds = [];
    mapBounds.add(LatLng(maxLat, maxLong));
    mapBounds.add(LatLng(minLat, minLong));

    // bail out if no data
    if (mapBounds.isEmpty) {
      return _NoDataScreen();
    }

    // regular or topo maps
    TileLayerOptions tileLayerOpts;
    if (widget.settingsOptions.useTopoMaps == true)
      tileLayerOpts = TileLayerOptions(
        urlTemplate: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
        subdomains: ['a', 'b', 'c'],
        opacity: 0.85,
      );
    else
      tileLayerOpts = TileLayerOptions(
        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        subdomains: ['a', 'b', 'c'],
      );

    // zoom out and in
    void _zoomOut() {
      mapController.onReady.whenComplete(() => mapController.move(mapController.center, mapController.zoom - 1));
    }

    void _zoomIn() {
      // limit the zoom level
      double newZoom = mapController.zoom + 1;
      if (newZoom > 18) newZoom = 18;
      mapController.onReady.whenComplete(() => mapController.move(mapController.center, newZoom));
    }

    return Scaffold(
        body: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            bounds: LatLngBounds.fromPoints(mapBounds),
            boundsOptions: FitBoundsOptions(
              padding: EdgeInsets.all(15.0),
            ),
            plugins: [
              TappablePolylineMapPlugin(),
            ],
          ),
          layers: [
            tileLayerOpts,
            TappablePolylineLayerOptions(
              polylines: theSegmentPolylines,
              polylineCulling: true,
              pointerDistanceTolerance: 15,
              onTap: (TaggedPolyline polyline) => _mapInfoAlert(context, polyline.tag, theTrailNamesMap, theTrailLengthMap),
              onMiss: () => debugPrint("No polyline tapped"),
            ),
            MarkerLayerOptions(markers: theTrailNameMarkers),
          ],
        ),

        // zoom in and out buttons
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "zoomIn",
              onPressed: _zoomIn,
              tooltip: 'Zoom In',
              child: Icon(Icons.add_circle_outline_rounded),
            ),
            SizedBox(
              height: 5,
            ),
            FloatingActionButton(
              heroTag: "zoomOut",
              onPressed: _zoomOut,
              tooltip: 'Zoom Out',
              child: Icon(Icons.remove_circle_outline_rounded),
            ),
          ],
        ));
  }
}

// ----
class _NoDataScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('No data for this map!')));
  }
}

// ----
// Decode Google encodedLocations to a List of LatLng
List<LatLng> _buildPolyLineForMap(String encodedValue) {
  List<LatLng> poly = [];
  const mask = ~0x20;

  var iter = encodedValue.runes.iterator;
  var parts = [];
  var part = <int>[];
  while (iter.moveNext()) {
    var byte = iter.current - 63;
    part.add(byte & mask);
    // debugPrint(iter.current.toString());
    if ((byte & 0x20) != 0x20) {
      // debugPrint('break');
      parts.add(part);
      part = [];
    }
  }
  if (part.isNotEmpty) {
    parts.add(part);
  }

  var lastLat = 0.0;
  var lastLng = 0.0;
  var count = 0;

  for (var p in parts) {
    var value = 0;
    for (var byte in p.reversed) {
      value = (value << 5) | byte;
    }
    var invert = (value & 1) == 1;
    value = value >> 1;
    if (invert) {
      // value = -value;
      // this should be the ~ operator (rather than negative) to invert the encoding of the int but unfortunately
      // cannot get ~ to work correctly on Chrome w/o jumping through some hoops
      value = (~BigInt.from(value)).toInt();
    }
    var result = value.toDouble() / 1E5;

    if (count % 2 == 0) {
      lastLat += result;
    } else {
      lastLng += result;
      // debugPrint('($lastLat, $lastLng)');
      poly.add(LatLng(lastLat, lastLng));
    }
    count++;
  }

  return poly;
}

// ----
class MapData {
  Text mapName;
  double percentComplete;
  List<SegmentSummary> completedSegs = [];
  List<SegmentSummary> remainingSegs = [];
  Color completedSegColor = Colors.blue;
  Color remainingSegColor = Colors.redAccent;

  bool isMapSummary = false;

  // by default code will use Json file in the assets for the trail segment data
  // - change the following to false to pull the trail segment data out of Firestore
  bool useJsonForSegments = true;
}

// ----
class SegmentSummary {
  final String name;
  final String segmentNameId;
  final String encodedLocations;
  final int length;
  final String trailId;

  // latLong list after decoding
  List<LatLng> latLong;
  // bounds
  Map<String, dynamic> boundsMap;

  final DocumentReference reference;

  SegmentSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['segmentId'] != null),
        assert(map['encodedLocations'] != null),
        name = map['name'],
        segmentNameId = map['segmentId'],
        latLong = map['latLong'],
        length = map['length'],
        trailId = map['trailId'],
        encodedLocations = map['encodedLocations'],
        boundsMap = map['bounds'];

  SegmentSummary.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
