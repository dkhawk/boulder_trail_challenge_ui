import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gpx/gpx.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:path/path.dart' as path;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'dart:math' as math show pow;

import 'dart:convert';
//
// View an encoded preview map:
// https://maps.googleapis.com/maps/api/staticmap?size=300x300&maptype=roadmap&path=enc:u_fsFnjtaSKdGs@~BgB_@eBmDsEvAcBfAeANkBoAoA`@uCHgAYiFdCuAm@c@ViAkAqBKeB_BuAUuB|@}Hx@aIbDeEFuBv@s@a@aK\\{Fw@qJz@sHi@iDd@yC`Ca@xAb@tGfHjAqB~AdADl@r@wARbA\\Pn@iAbA`@ROrAVzA_@d@J|@Xp@S`AmA\\}@~AbC]Fx@j@l@ObAOLpAlA|HwFpHgBn@uAxBWd@mArG{DdIqJtFwAtC}BxAGhBmAhDGfCyA~BK~@uA}@}Dt@wAvD]lArAjEVzC{BdBPfBi@z@f@nA[zA`BzCi@DiAxBNPm@hBTnBtCtBA@_Kw@s@h@oBj@q@rDEbBu@XxCdGmOVh@gB|J`@fAjEWhAoB?`Fh@d@\\oBvA]tBmBjBkEtAr@lBO`ChGvAz@g@xAPrAfCr@vAgA?pBr@}@z@kDz@]|Ar@p@rFp@@t@eBWd@Nz@w@xBVVq@fA`@|@yAj@v@v@kABf@^UL_CFhAnACrAxAjCjDA~ClDr@zBKlAg@xCl@PyAVqEjDkD`@_@`ADpAwAbD[O|AdEk@bBtAlEQxGtAnDbDNpD{Aa@`@b@NSp@dKbAjBaBjBYd@_ArBB|BhAdC}DbG_BlAf@xBYjA_Cz@IdAeCvAy@`@{AdCqCxBUrCn@AdAoBbC~@bB`Bt@xEa@fBsAn@{BIw@h@KEk@l@I?g@v@FAe@lCiA\\y@dGwA?iA|AFJ_@]q@NqBjAxB`BP`CxB?{AhCqBQcA`Aq@FwBs@a@z@p@YbAPZ_Ap@PjAkC~AEfBiBsByBQgAiCDhDA\\yAGO`@XX_Et@aGnD[lAu@FDf@{@BA|A[Cb@Pk@nAsBlAsEn@gCuAc@}@v@G`AmDuC_AkAN}AbA}@x@c@bCcAXwBhC?t@c@Uo@~AgDn@eIh@oCfEoCgAmBVKo@mCUiCkBe@DHd@gAjAwDwK{BsCsF}A{CjB^mAwAmC?}@^J^uBf@U^sDxFqArCmCrADu@k@l@eEq@mCyCmDwDLqAiCMaBw@eAnCK_@{@fAHe@kArASg@y@`@sAYSx@gA^eCe@AsA~A[y@j@qJgGt@u@jBB`AgAnB}@F_BuA@{CeDgEc@aBiEm@yB`EmBlBkAVm@pBe@wBRiC_BjBuDZc@q@bBsKUc@kGnOQ}C}G`Ao@p@D~@&key=AIzaSyAhdVJIK052gJzuSxvUuhKZPNgXdyaA9ig

// Simple, first implementation.  Just list all of the activities since Jan 1, 2021
// curl -X GET "https://www.strava.com/api/v3/athlete/activities?after=1609459200&per_page=30" -H "accept: application/json" -H "authorization: Bearer 0275e53d4c133d20f8fd628954b031faab7f9cfe"
//
// Check if the authorization token has expired
//

// ----
class ImportGPXActivities extends StatefulWidget {
  @override
  _ImportGPXActivitiesState createState() => _ImportGPXActivitiesState();
}

// ----
class _ImportGPXActivitiesState extends State<ImportGPXActivities> {
  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User>();
    String userName = firebaseUser.email;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('GPX File Import'),
          ],
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Spacer(),
            Image(image: AssetImage('assets/images/UploadFile.png')),
            Spacer(),
            ElevatedButton(
              child: Text(
                  'Press here to select the GPX files that you want to import'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return Scaffold(
                        body: PickFilesScreen(userName),
                      );
                    },
                  ),
                );
              },
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

// ----
class PickFilesScreen extends StatefulWidget {
  PickFilesScreen(this.userName);
  final userName;

  @override
  _PickFilesScreenState createState() => _PickFilesScreenState(userName);
}

// ----
class _PickFilesScreenState extends State<PickFilesScreen> {
  _PickFilesScreenState(this.userName);
  final userName;

  int numFilesUploaded = 0;

  // ----
  Future<String> _pickFiles(String userName) async {
    // TODO: support other formats when we can (tcx, fit?)
    numFilesUploaded = 0;
    FilePickerResult result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData: true,
      allowMultiple: true,
    );

    if ((result == null) || (result.count == 0)) {
      print('No files selected');
      return 'done';
    }

    if ((result != null) && (result.count != 0)) {
      print(result.names.toString());
      result.files.forEach(
        (file) async {
          String fileNameString = '';
          try {
            // the gpx string:
            String gpxDataString = Utf8Decoder().convert(file.bytes);

            // create gpx from the string
            Gpx xmlGpx = GpxReader().fromString(gpxDataString);
            String gpxDateTime = '';
            if ((xmlGpx.metadata != null) && (xmlGpx.metadata.time != null))
              gpxDateTime = xmlGpx.metadata.time.toString();

            String uploadDateTime = DateTime.now().toUtc().toString();

            // convert tracks in the Gpx to google encoded tracks
            List<String> encodedTrackStrings = [];
            encodedTrackStrings = _gpxToGoogleEncodedTrack(xmlGpx);

            //=============================
            // grid
            Map coordinatesToSegmentsMap = Map<String, dynamic>();

            double minLatitude = 39.9139860039965;
            double minLongitude = -105.406643752203;
            double maxLatitude = 40.1164546952824;
            double maxLongitude = -105.131874521385;

            double latDegrees = maxLatitude - minLatitude;
            double lngDegrees = maxLongitude - minLongitude;

            int width = 235;
            int height = 225;
            // loop over all separate track and track segments
            for (int iTrack = 0; iTrack < xmlGpx.trks.length; iTrack++) {
              Trk theTrack = xmlGpx.trks[iTrack];
              for (int iSeg = 0; iSeg < theTrack.trksegs.length; iSeg++) {
                Trkseg trackSeg = theTrack.trksegs[iSeg];

                trackSeg.trkpts.forEach((waypoint) {
                  // grid map
                  int gridx =
                  (((waypoint.lon - minLongitude) / lngDegrees) * width)
                      .toInt();
                  int gridy =
                  (((waypoint.lat - minLatitude) / latDegrees) * height)
                      .toInt();

                  String segID = '';
                  if (theTrack.extensions
                      .containsKey('ogr:GISPROD3OSMPTrailsOSMPSEGMENTID')) {
                    segID = theTrack
                        .extensions['ogr:GISPROD3OSMPTrailsOSMPSEGMENTID']
                        .toString();
                  }

                  String key = '${gridx},${gridy}';

                  List segmentsList = [];
                  if (coordinatesToSegmentsMap.containsKey(key)) {
                    segmentsList = coordinatesToSegmentsMap[key];
                  }
                  if (segmentsList.contains(segID) == false) {
                    segmentsList.add(segID);
                  }

                  coordinatesToSegmentsMap[key] = segmentsList;
                });
              }
            }

            Map gridMap = Map<String, dynamic>();
            Map boundsMap = Map<String, dynamic>();
            boundsMap['minLatitude'] = minLatitude;
            boundsMap['minLongitude'] = minLongitude;
            boundsMap['maxLatitude'] = maxLatitude;
            boundsMap['maxLongitude'] = maxLongitude;

            gridMap['bounds'] = boundsMap;
            gridMap['width'] = width;
            gridMap['height'] = height;
            gridMap['coordinatesToSegments'] = coordinatesToSegmentsMap;
            String jsonStringGridMap = jsonEncode(gridMap);
            print('jsonStringGridMap');
            print(jsonStringGridMap);
            //=============================

            // base name for the document in firestore
            String baseTrackName = path.basenameWithoutExtension(file.name);

            // upload the google encoded tracks
            for (int iTrack = 0;
                iTrack < encodedTrackStrings.length;
                iTrack++) {
              // change the gpx file extension
              // - the new file extension '.gencoded' approximates 'Google encoded'
              String encodedTrackUploadLocation =
                  baseTrackName + '_trackSeg' + iTrack.toString() + '.gencoded';

              // a map for the uploaded data
              Map<String, dynamic> importedTrackMap = {
                'originalFileName': file.name,
                'gpxDateTime': gpxDateTime,
                'uploadDateTime': uploadDateTime,
                'userName': userName,
                'encodedLocation': encodedTrackStrings[iTrack],
                'processed': false,
              };

              // do the actual upload if not empty
              // if (encodedTrackStrings[iTrack].isNotEmpty) {
              //   FirebaseFirestore.instance
              //       .collection('athletes')
              //       .doc(userName)
              //       .collection('importedData')
              //       .doc(encodedTrackUploadLocation)
              //       .set(importedTrackMap);
              // } else {
              //   print(
              //       'Uploading GPX activity failed: = <> $uploadDateTime <> encodedTrackUploadLocation is EMPTY');
              // }
            }

            fileNameString = path.basenameWithoutExtension(file.name);

            print(
                'pickFiles: $fileNameString from $gpxDateTime was uploaded as a google encoded string');
            numFilesUploaded++;
          } catch (e) {
            print(e);
          }
        },
      );
    }

    print('Number of gpx files uploaded = $numFilesUploaded');

    // get and update the number of files uploaded
    // - this is used to trigger the cloud script that processes the uploaded files
    DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
        .collection('athletes')
        .doc(userName)
        .collection('importedData')
        .doc('UploadStats')
        .get();
    int numFilesPreviouslyUploaded = documentSnapshot.get('numFilesUploaded');
    int totalFilesUploaded = numFilesPreviouslyUploaded + numFilesUploaded;
    print('Number of files previously uploaded = $numFilesPreviouslyUploaded');
    print(
        'Total number of files gpx or Strava files uploaded = $totalFilesUploaded');
    Map<String, dynamic> numFilesUploadedMap = {
      'numFilesUploaded': totalFilesUploaded,
    };
    await FirebaseFirestore.instance
        .collection('athletes')
        .doc(userName)
        .collection('importedData')
        .doc('UploadStats')
        .set(numFilesUploadedMap, SetOptions(merge: true));

    return 'done';
  }

  // ----
  Widget _numFilesAlertWidget(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/TopoMapPattern.png"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.grey, BlendMode.lighten),
        ),
      ),
      width: double.infinity,
      child: AlertDialog(
        title: Text('GPX File Import', style: TextStyle(color: Colors.white)),
        content: Text(
          numFilesUploaded.toString() + ' file(s) uploaded',
          style: TextStyle(fontSize: 15, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        shape:
            RoundedRectangleBorder(borderRadius: new BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ----
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _pickFiles(userName),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.hasData && (snapshot.data == 'done')) {
          print('snapshot.hasData and done');
          return _numFilesAlertWidget(context);
        } else {
          return Center(
            child: Column(
              children: [
                Spacer(
                  flex: 5,
                ),
                SizedBox(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  width: 40,
                  height: 40,
                ),
                Spacer(),
                Text('Uploading GPX data...',
                    style: TextStyle(color: Colors.black, fontSize: 12.0)),
                Spacer(
                  flex: 5,
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

// ----
List<String> _gpxToGoogleEncodedTrack(Gpx xmlGpx) {
  // pull out the tracks
  List<String> encodedTracks = [];
  String numtrks = 'number of trks = ' + xmlGpx.trks.length.toString();
  print(numtrks);

  Map encodedTheSegmentsMap = Map<String, dynamic>();

  // loop over all separate track and track segments
  for (int iTrack = 0; iTrack < xmlGpx.trks.length; iTrack++) {
    Trk theTrack = xmlGpx.trks[iTrack];
    // String numtrksegs =
    //     'number of trksegs = ' + theTrack.trksegs.length.toString();
    //print(numtrksegs);

    for (int iSeg = 0; iSeg < theTrack.trksegs.length; iSeg++) {
      Trkseg trackSeg = theTrack.trksegs[iSeg];

      double minLatitude = double.infinity;
      double minLongitude = double.infinity;
      double maxLatitude = -double.infinity;
      double maxLongitude = -double.infinity;

      List<List<num>> trackPoints = [];
      trackSeg.trkpts.forEach((waypoint) {

        if (waypoint.lat > maxLatitude) maxLatitude = waypoint.lat;
        if (waypoint.lon > maxLongitude) maxLongitude = waypoint.lon;

        if (waypoint.lat < minLatitude) minLatitude = waypoint.lat;
        if (waypoint.lon < minLongitude) minLongitude = waypoint.lon;

        trackPoints.add([waypoint.lat, waypoint.lon]);
      });

      // Test:
      // trackPoints.add([38.5, -120.2]);
      // trackPoints.add([40.7, -120.95]);
      // trackPoints.add([43.252, -126.453]);
      // encoded track for these three points is `_p~iF~ps|U_ulLnnqC_mqNvxq`@'

      String encodedTrack = encodePolyline(trackPoints);
      encodedTracks.add(encodedTrack);

      // dcodePolyline if desired for test:
      // print('encoded track: ');
      // print(encodedTrack);
      //
      // List<List<num>> testReturn = decodePolyline_local(encodedTrack);
      // print(testReturn.toString());


      //=============================
      // To update the encoded-locations.json & grid-data.json:
      //
      // 1) Get latest OSMP trails data in geoJson format from https://open-data.bouldercolorado.gov/datasets; drive down to the
      // download options and grab geoJson file
      // 2) Convert the geoJson file to gpx using https://mygeodata.cloud/converter/geojson-to-gpx  This site preserves comments
      // in the extensions while some others do not. This step costs a few dollars!
      // 3) Run code. Import the gpx file. The encoded-locations.json & grid-data.json will be printed into the logs. Copy/paste
      // these into appropriate files.


      //=============================
      // map for encoded_locations
      //if (theTrack.extensions.isNotEmpty) {

      //print('extensions ${theTrack.extensions}');
      if (theTrack.extensions.isNotEmpty) {
        //print('extracting extensions');

        //Map<String,String> extensions = jsonDecode(theTrack.desc);

        // length: in meters
        int length = 0;
        if (theTrack.extensions
            .containsKey('ogr:GISPROD3OSMPTrailsOSMPMEASUREDFEET')) {
          length = (double.parse(theTrack
              .extensions['ogr:GISPROD3OSMPTrailsOSMPMEASUREDFEET']) ~/
              3.2808);  // feet to meters
        }
        if ((length < 1) &&
            (theTrack.extensions
                .containsKey('ogr:GISPROD3OSMPTrailsOSMPMILEAGE'))) {
          length = (double.parse(theTrack
              .extensions['ogr:GISPROD3OSMPTrailsOSMPMILEAGE']) *
              1609.34)
              .toInt();  // miles to meters
        }

        //print(' segment length $length');

        Map<String, dynamic> boundsMap = {
          'minLatitude': minLatitude,
          'minLongitude': minLongitude,
          'maxLatitude': maxLatitude,
          'maxLongitude': maxLongitude,
        };
        Map<String, dynamic> encodedSegmentMap = {
          'trailId': theTrack.extensions['ogr:GISPROD3OSMPTrailsOSMPTRLID'],
          'segmentId':
          theTrack.extensions['ogr:GISPROD3OSMPTrailsOSMPSEGMENTID'],
          'name': theTrack.extensions['ogr:GISPROD3OSMPTrailsOSMPTRAILNAME'],
          'length': length,
          'bounds': boundsMap,
          'encodedLocations': encodedTrack,
        };

        encodedTheSegmentsMap[
        theTrack.extensions['ogr:GISPROD3OSMPTrailsOSMPSEGMENTID']] =
            encodedSegmentMap;
      }
    }
  }

  String jsonString = jsonEncode(encodedTheSegmentsMap);
  print('jsonStringEncodedSegments');
  print(jsonString);
  //=============================

  return encodedTracks;
}

// ----
// Note that the decodePolyline algorithm in the library uses the ~ operator that does not work on Chrome
// -- the following is a hacked version
// ----
//
/// Decodes [polyline] `String` via inverted
/// [Encoded Polyline Algorithm](https://developers.google.com/maps/documentation/utilities/polylinealgorithm?hl=en)
List<List<num>> decodePolyline_local(String polyline, {int accuracyExponent = 5}) {
  final accuracyMultiplier = math.pow(10, accuracyExponent);
  final List<List<num>> coordinates = [];

  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < polyline.length) {
    int char;
    int shift = 0;
    int result = 0;

    /// Method for getting **only** `1` coorditane `latitude` or `longitude` at a time
    int getCoordinate() {
      /// Iterating while value is grater or equal of `32-bits` size
      do {
        /// Substract `63` from `codeUnit`.
        char = polyline.codeUnitAt(index++) - 63;

        /// `AND` each `char` with `0x1f` to get 5-bit chunks.
        /// Then `OR` each `char` with `result`.
        /// Then left-shift for `shift` bits
        result |= (char & 0x1f) << shift;
        shift += 5;
      } while (char >= 0x20);

      /// Inversion of both:
      ///
      ///  * Left-shift the `value` for one bit
      ///  * Inversion `value` if it is negative
      final value = result >> 1;
      final coordinateChange =
      //(result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      (result & 1) != 0 ? (~BigInt.from(value)).toInt() : value;

      /// It is needed to clear `shift` and `result` for next coordinate.
      shift = result = 0;

      return coordinateChange;
    }

    lat += getCoordinate();
    lng += getCoordinate();

    coordinates.add([lat / accuracyMultiplier, lng / accuracyMultiplier]);
  }

  return coordinates;
}
