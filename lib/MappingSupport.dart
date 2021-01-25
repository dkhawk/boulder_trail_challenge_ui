import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/trail_progress_list_widget.dart';
import 'package:provider/provider.dart';

// ----
Widget displayMap(
    BuildContext context, TrailSummary trail, SettingsOptions settingsOptions) {
  MapData inputMapData = new MapData();
  inputMapData.mapName = Text(trail.name);
  inputMapData.percentComplete = trail.percentDone;

  Navigator.push(context, MaterialPageRoute<void>(
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
                valueColor: new AlwaysStoppedAnimation<Color>(
                    inputMapData.completedSegColor),
                minHeight: 3,
              )
            ],
          ),
        ),
        body: _LoadDisplayMapData(trail, inputMapData, settingsOptions),
      );
    },
  ));

  return _NoDataScreen();
}

// ----
Widget displayMapSummary(BuildContext context, MapData inputMapSummaryData,
    SettingsOptions settingsOptions) {
  double percentDone = inputMapSummaryData.percentComplete;

  Navigator.push(context, MaterialPageRoute<void>(
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
                valueColor: new AlwaysStoppedAnimation<Color>(
                    inputMapSummaryData.completedSegColor),
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

    Stream theStream = FirebaseFirestore.instance
        .collection('athletes')
        .doc(firebaseUser.email)
        .collection("trailStats")
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: theStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();

        // for each trail add all the completed and remaining segments to an overallTrailSummary
        TrailSummary overallTrailSummary = new TrailSummary();
        snapshot.data.docs.forEach((DocumentSnapshot document) {
          TrailSummary theSummaryForTheTrail =
              TrailSummary.fromSnapshot(document);
          overallTrailSummary.completedSegs
              .addAll(theSummaryForTheTrail.completedSegs);
          overallTrailSummary.remainingSegs
              .addAll(theSummaryForTheTrail.remainingSegs);
        });

        return _LoadDisplayMapData(
            overallTrailSummary, inputMapSummaryData, settingsOptions);
      },
    );
  }
}

//----
class _LoadDisplayMapData extends StatelessWidget {
  _LoadDisplayMapData(this.trail, this.inputMapData, this.settingsOptions);
  final TrailSummary trail;
  final MapData inputMapData;
  final SettingsOptions settingsOptions;

  @override
  Widget build(BuildContext context) {
    Stream theStream;
    if (inputMapData.isMapSummary) {
      // get all the segments
      theStream = FirebaseFirestore.instance.collection('segments').snapshots();
    } else {
      // get only the segments for the given trail name
      theStream = FirebaseFirestore.instance
          .collection('segments')
          .where('name', isEqualTo: trail.name)
          .snapshots();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: theStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _populateMapData(
            context, trail, inputMapData, settingsOptions, snapshot.data.docs);
      },
    );
  }
}

// ----
Widget _populateMapData(
    BuildContext context,
    TrailSummary trail,
    MapData inputMapData,
    SettingsOptions settingsOptions,
    List<DocumentSnapshot> snapshot) {
  // build data for the trail map
  inputMapData.completedSegs = [];
  inputMapData.remainingSegs = [];

  // go through the list of segments for this trail pulled from firestore
  snapshot.forEach((DocumentSnapshot document) {
    SegmentSummary segment = SegmentSummary.fromSnapshot(document);
    String segmentNameId = segment.segmentNameId;
    String encodedLocations = segment.encodedLocations;
    segment.latLong = _buildPolyLineForMap(encodedLocations);

    // is this segment completed or remaining
    if (List.castFrom(trail.completedSegs).contains(segmentNameId))
      inputMapData.completedSegs.add(segment);
    else if (List.castFrom(trail.remainingSegs).contains(segmentNameId))
      inputMapData.remainingSegs.add(segment);
    else
      assert("No segment data" != null);
  });

  return _CreateFlutterMap(inputMapData, settingsOptions);
}

// ----
class _CreateFlutterMap extends StatelessWidget {
  _CreateFlutterMap(this.theMapData, this.settingsOptions);
  final MapData theMapData;
  final SettingsOptions settingsOptions;

  @override
  Widget build(BuildContext context) {
    // keep track of all LatLng's that will be displayed (granted not efficient)
    List<LatLng> mapBounds = [];

    // trail or trail segment names
    List<Marker> theTrailNameMarkers = [];

    // completed segments in one color
    List<Polyline> theSegmentPolylines = [];
    theMapData.completedSegs.forEach((SegmentSummary segment) {
      Polyline polyline = new Polyline(
          points: segment.latLong,
          strokeWidth: 4.0,
          color: theMapData.completedSegColor);
      theSegmentPolylines.add(polyline);
      mapBounds += segment.latLong;

      // trail or trail segment names on the map (optionally)
      if (settingsOptions.displayTrailNames ||
          settingsOptions.displaySegmentNames) {
        if (polyline.points.isNotEmpty) {
          // approx center of polyline
          // int pntID = ((polyline.points.length) / 2).toInt();
          int pntID = polyline.points.length ~/ 2;

          // the marker with the trail or segment name
          String markerString = segment.name;
          if (settingsOptions.displaySegmentNames)
            markerString = segment.segmentNameId;

          Marker segNameMarker = new Marker(
            width: 80.0,
            point: polyline.points[pntID],
            builder: (ctx) => new Container(
              child:
                  new Text(markerString, style: new TextStyle(fontSize: 12.0)),
            ),
          );

          theTrailNameMarkers.add(segNameMarker);
        }
      }
    });

    // remaining segments in another color
    theMapData.remainingSegs.forEach((SegmentSummary segment) {
      Polyline polyline = new Polyline(
          points: segment.latLong,
          strokeWidth: 4.0,
          color: theMapData.remainingSegColor);
      theSegmentPolylines.add(polyline);
      mapBounds += segment.latLong;

      // trail or trail segment names on the map (optionally)
      if (settingsOptions.displayTrailNames ||
          settingsOptions.displaySegmentNames) {
        if (polyline.points.isNotEmpty) {
          // approx center of polyline
          // int pntID = ((polyline.points.length) / 2).toInt();
          int pntID = polyline.points.length ~/ 2;

          // the marker with the trail or segment name
          String markerString = segment.name;
          if (settingsOptions.displaySegmentNames)
            markerString = segment.segmentNameId;

          Marker segNameMarker = new Marker(
            width: 80.0,
            point: polyline.points[pntID],
            builder: (ctx) => new Container(
              child:
                  new Text(markerString, style: new TextStyle(fontSize: 12.0)),
            ),
          );

          theTrailNameMarkers.add(segNameMarker);
        }
      }
    });

    // bail out if no data
    if (mapBounds.isEmpty) {
      return _NoDataScreen();
    }

    // regular or topo maps
    TileLayerOptions tileLayerOpts;
    if (settingsOptions.useTopoMaps == true)
      tileLayerOpts = new TileLayerOptions(
        urlTemplate: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
        subdomains: ['a', 'b', 'c'],
        opacity: 0.85,
      );
    else
      tileLayerOpts = new TileLayerOptions(
        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        subdomains: ['a', 'b', 'c'],
      );

    // zoom out and in
    MapController mapController = new MapController();
    void _zoomOut() {
      if (mapController.ready)
        mapController.move(mapController.center, mapController.zoom - 1);
    }

    void _zoomIn() {
      if (mapController.ready) {
        double newZoom = mapController.zoom + 1;
        if (newZoom > 18) newZoom = 18;
        mapController.move(mapController.center, newZoom);
      }
    }

    return Scaffold(
        body: new FlutterMap(
          mapController: mapController,
          options: MapOptions(
            bounds: LatLngBounds.fromPoints(mapBounds),
            boundsOptions: FitBoundsOptions(
              padding: EdgeInsets.all(15.0),
            ),
            maxZoom: 18,
          ),
          layers: [
            tileLayerOpts,
            new PolylineLayerOptions(polylines: theSegmentPolylines),
            new MarkerLayerOptions(markers: theTrailNameMarkers),
          ],
        ),

        // zoom in and out buttons
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          //crossAxisAlignment: CrossAxisAlignment.end,
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
      poly.add(new LatLng(lastLat, lastLng));
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
}

// ----
class SegmentSummary {
  final String name;
  final String segmentNameId;
  final String encodedLocations;
  List<LatLng> latLong;

  final DocumentReference reference;

  SegmentSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['segmentId'] != null),
        assert(map['encodedLocations'] != null),
        name = map['name'],
        segmentNameId = map['segmentId'],
        latLong = map['latLong'],
        encodedLocations = map['encodedLocations'];

  SegmentSummary.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
