import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'main.dart';

// ----
Widget DisplayMap(BuildContext context, TrailSummary trail) {

  mapData inputMapData = new mapData();
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
              Text((trail.percentDone*100).toStringAsFixed(2) + '%',style: TextStyle(fontSize: 12.0,)),
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
}

//----
class _LoadDisplayMapData extends StatelessWidget {
  _LoadDisplayMapData(this.trail, this.inputMapData);
  final TrailSummary trail;
  final mapData inputMapData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance
          .collection('segments')
          .where('name', isEqualTo: trail.name)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _PopulateMapData(context, trail, inputMapData, snapshot.data.documents);
      },
    );
  }
}

// ----
Widget _PopulateMapData(BuildContext context, TrailSummary trail, mapData inputMapData, List<DocumentSnapshot> snapshot) {
  // build data for the trail map
  inputMapData.completedSegs = [];
  inputMapData.remainingSegs = [];

  List<String> completedSegs = List.castFrom(trail.completedSegs);
  List<String> remainingSegs = List.castFrom(trail.remainingSegs);

  // go through the list of segments for this trail pulled from firestore
  snapshot.forEach((DocumentSnapshot document) {
    segmentSummary segment = segmentSummary.fromSnapshot(document);
    String segmentNameId = segment.segmentNameId;
    String encodedLocations = segment.encodedLocations;
    segment.latLong = _buildPolyLineForMap(encodedLocations);

    // is this segment completed or remaining
    if(List.castFrom(trail.completedSegs).contains(segmentNameId))
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
  final mapData theMapData;

  @override
  Widget build(BuildContext context) {

    // keep track of all LatLng's that will be displayed (granted not efficient)
    List<LatLng> mapBounds = [];

    // completed segments in one color
    List<Polyline> theSegmentPolylines = [];
    theMapData.completedSegs.forEach((segmentSummary segment) {
      Polyline polyline = new Polyline(
          points: segment.latLong,
          strokeWidth: 2.0,
          color: theMapData.completedSegColor);
      theSegmentPolylines.add(polyline);
      mapBounds += segment.latLong;
    });

    // remaining segments in another color
    theMapData.remainingSegs.forEach((segmentSummary segment) {
      Polyline polyline = new Polyline(
          points: segment.latLong,
          strokeWidth: 2.0,
          color: theMapData.remainingSegColor);
      theSegmentPolylines.add(polyline);
      mapBounds += segment.latLong;
    });

    // bail out if no data
    if(mapBounds.isEmpty) {
      return _noDataScreen();
    }

    // pop up the map
    return new FlutterMap(
      options: new MapOptions(
          bounds: LatLngBounds.fromPoints(mapBounds),
          boundsOptions: FitBoundsOptions(
            padding: EdgeInsets.all(15.0),
          )),
      layers: [
        new TileLayerOptions(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c']),
        new PolylineLayerOptions(
          polylines: theSegmentPolylines
        ),
      ],
    );
  }
}

// ----
class _noDataScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
          child: Text('No data for this map!')
        )
    );
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
class mapData {
  Text mapName;
  double percentComplete;
  List<segmentSummary> completedSegs = [];
  List<segmentSummary> remainingSegs = [];
  Color completedSegColor = Colors.orange;
  Color remainingSegColor = Colors.black45;
}

// ----
class segmentSummary {
  final String name;
  final String segmentNameId;
  final String encodedLocations;
  List<LatLng> latLong;

  final DocumentReference reference;

  segmentSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['segmentId'] != null),
        assert(map['encodedLocations'] != null),

        name = map['name'],
        segmentNameId = map['segmentId'],
        latLong = map['latLong'],
        encodedLocations = map['encodedLocations'];

  segmentSummary.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);
}
