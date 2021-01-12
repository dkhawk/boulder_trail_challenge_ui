import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'home_page.dart';

// ----
Widget displayMap(BuildContext context, TrailSummary trail) {
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
                valueColor: new AlwaysStoppedAnimation<Color>(inputMapData.completedSegColor),
                minHeight: 3,
              )
            ],
          ),
        ),
        body: _LoadDisplayMapData(trail, inputMapData),
      );
    },
  ));

  return _NoDataScreen();
}

//----
class _LoadDisplayMapData extends StatelessWidget {
  _LoadDisplayMapData(this.trail, this.inputMapData);
  final TrailSummary trail;
  final MapData inputMapData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('segments').where('name', isEqualTo: trail.name).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _populateMapData(context, trail, inputMapData, snapshot.data.docs);
      },
    );
  }
}

// ----
Widget _populateMapData(BuildContext context, TrailSummary trail, MapData inputMapData, List<DocumentSnapshot> snapshot) {
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

  return _CreateFlutterMap(inputMapData);
}

// ----
class _CreateFlutterMap extends StatelessWidget {
  _CreateFlutterMap(this.theMapData);
  final MapData theMapData;

  @override
  Widget build(BuildContext context) {
    // keep track of all LatLng's that will be displayed (granted not efficient)
    List<LatLng> mapBounds = [];

    // completed segments in one color
    List<Polyline> theSegmentPolylines = [];
    theMapData.completedSegs.forEach((SegmentSummary segment) {
      Polyline polyline = new Polyline(points: segment.latLong, strokeWidth: 2.0, color: theMapData.completedSegColor);
      theSegmentPolylines.add(polyline);
      mapBounds += segment.latLong;
    });

    // remaining segments in another color
    theMapData.remainingSegs.forEach((SegmentSummary segment) {
      Polyline polyline = new Polyline(points: segment.latLong, strokeWidth: 2.0, color: theMapData.remainingSegColor);
      theSegmentPolylines.add(polyline);
      mapBounds += segment.latLong;
    });

    // bail out if no data
    if (mapBounds.isEmpty) {
      return _NoDataScreen();
    }

    // pop up the map
    return new FlutterMap(
      options: new MapOptions(
          bounds: LatLngBounds.fromPoints(mapBounds),
          boundsOptions: FitBoundsOptions(
            padding: EdgeInsets.all(15.0),
          )),
      layers: [
        new TileLayerOptions(urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", subdomains: ['a', 'b', 'c']),
        new PolylineLayerOptions(polylines: theSegmentPolylines),
      ],
    );
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
List<LatLng> _buildPolyLineForMap(String encoded) {
  // The following code used to decode the polyline was
  // written by Dammy Ololade
  List<LatLng> poly = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;
    LatLng p = new LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
    poly.add(p);
  }
  return poly;
}

// ----
class MapData {
  Text mapName;
  double percentComplete;
  List<SegmentSummary> completedSegs = [];
  List<SegmentSummary> remainingSegs = [];
  Color completedSegColor = Colors.orange;
  Color remainingSegColor = Colors.black45;
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

  SegmentSummary.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
