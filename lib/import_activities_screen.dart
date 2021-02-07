import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
//import 'dart:convert';
//
// View an encoded preview map:
// https://maps.googleapis.com/maps/api/staticmap?size=300x300&maptype=roadmap&path=enc:u_fsFnjtaSKdGs@~BgB_@eBmDsEvAcBfAeANkBoAoA`@uCHgAYiFdCuAm@c@ViAkAqBKeB_BuAUuB|@}Hx@aIbDeEFuBv@s@a@aK\\{Fw@qJz@sHi@iDd@yC`Ca@xAb@tGfHjAqB~AdADl@r@wARbA\\Pn@iAbA`@ROrAVzA_@d@J|@Xp@S`AmA\\}@~AbC]Fx@j@l@ObAOLpAlA|HwFpHgBn@uAxBWd@mArG{DdIqJtFwAtC}BxAGhBmAhDGfCyA~BK~@uA}@}Dt@wAvD]lArAjEVzC{BdBPfBi@z@f@nA[zA`BzCi@DiAxBNPm@hBTnBtCtBA@_Kw@s@h@oBj@q@rDEbBu@XxCdGmOVh@gB|J`@fAjEWhAoB?`Fh@d@\\oBvA]tBmBjBkEtAr@lBO`ChGvAz@g@xAPrAfCr@vAgA?pBr@}@z@kDz@]|Ar@p@rFp@@t@eBWd@Nz@w@xBVVq@fA`@|@yAj@v@v@kABf@^UL_CFhAnACrAxAjCjDA~ClDr@zBKlAg@xCl@PyAVqEjDkD`@_@`ADpAwAbD[O|AdEk@bBtAlEQxGtAnDbDNpD{Aa@`@b@NSp@dKbAjBaBjBYd@_ArBB|BhAdC}DbG_BlAf@xBYjA_Cz@IdAeCvAy@`@{AdCqCxBUrCn@AdAoBbC~@bB`Bt@xEa@fBsAn@{BIw@h@KEk@l@I?g@v@FAe@lCiA\\y@dGwA?iA|AFJ_@]q@NqBjAxB`BP`CxB?{AhCqBQcA`Aq@FwBs@a@z@p@YbAPZ_Ap@PjAkC~AEfBiBsByBQgAiCDhDA\\yAGO`@XX_Et@aGnD[lAu@FDf@{@BA|A[Cb@Pk@nAsBlAsEn@gCuAc@}@v@G`AmDuC_AkAN}AbA}@x@c@bCcAXwBhC?t@c@Uo@~AgDn@eIh@oCfEoCgAmBVKo@mCUiCkBe@DHd@gAjAwDwK{BsCsF}A{CjB^mAwAmC?}@^J^uBf@U^sDxFqArCmCrADu@k@l@eEq@mCyCmDwDLqAiCMaBw@eAnCK_@{@fAHe@kArASg@y@`@sAYSx@gA^eCe@AsA~A[y@j@qJgGt@u@jBB`AgAnB}@F_BuA@{CeDgEc@aBiEm@yB`EmBlBkAVm@pBe@wBRiC_BjBuDZc@q@bBsKUc@kGnOQ}C}G`Ao@p@D~@&key=AIzaSyAhdVJIK052gJzuSxvUuhKZPNgXdyaA9ig

// Simple, first implementation.  Just list all of the activities since Jan 1, 2021
// curl -X GET "https://www.strava.com/api/v3/athlete/activities?after=1609459200&per_page=30" -H "accept: application/json" -H "authorization: Bearer 0275e53d4c133d20f8fd628954b031faab7f9cfe"
//
// Check if the authorization token has expired
//

// ----
class ImportActivitiesScreen extends StatefulWidget {
  @override
  _ImportActivitiesScreenState createState() => _ImportActivitiesScreenState();
}

// ----
class _ImportActivitiesScreenState extends State<ImportActivitiesScreen> {
  int numFilesUploaded = 0;

  @override
  Widget build(BuildContext context) {
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
            Image(image: AssetImage('images/UploadFile.png')),
            Spacer(),
            ElevatedButton(
              child: Text(
                  'Press here to select the GPX files that you want to import'),
              onPressed: () {
                _pickFiles().whenComplete(() => _numFilesAlert(context));
              },
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }

  // ----
  Future<void> _pickFiles() async {
    // TODO: support other formats when we can (tcx, fit?)

    numFilesUploaded = 0;
    FilePickerResult result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData: true,
      allowMultiple: true,
    );

    if ((result != null) && (result.count != 0)) {
      print(result.names.toString());
      result.files.forEach(
        (file) async {
          String fileNameString = '';
          try {
            // the gpx string:
            // TODO : eventually want to strip out extraneous data before upload
            // String dataString = Utf8Decoder().convert(file.bytes);

            String uploadLocation = 'testupload/' + file.name;
            firebase_storage.Reference ref =
                firebase_storage.FirebaseStorage.instance.ref().child(uploadLocation);
            firebase_storage.UploadTask uploadTask = ref.putData(file.bytes);

            print(uploadTask.storage.toString());

            fileNameString = file.name;
          } catch (e) {
            print(e);
          }

          if (fileNameString.isNotEmpty) {
            print('pickFiles: $fileNameString was uploaded');
            numFilesUploaded++;
          }
        },
      );
    }

    print('Number of files uploaded = $numFilesUploaded');
    return;
  }

// ----
  Future<void> _numFilesAlert(BuildContext context) async {
    print('_numFilesAlert dialog $numFilesUploaded');
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: 450.0),
          child: Dialog(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              SizedBox(
                height: 15,
              ),
              Text(
                numFilesUploaded.toString() + ' files uploaded',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(
                height: 10,
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 15.0,
                  ),
                ),
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
}
