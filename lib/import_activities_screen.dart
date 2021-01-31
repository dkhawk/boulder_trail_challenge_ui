import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart'; // For File Upload To Firestore
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For Image Picker
import 'package:path/path.dart' as Path;

//
// View an encoded preview map:
// https://maps.googleapis.com/maps/api/staticmap?size=300x300&maptype=roadmap&path=enc:u_fsFnjtaSKdGs@~BgB_@eBmDsEvAcBfAeANkBoAoA`@uCHgAYiFdCuAm@c@ViAkAqBKeB_BuAUuB|@}Hx@aIbDeEFuBv@s@a@aK\\{Fw@qJz@sHi@iDd@yC`Ca@xAb@tGfHjAqB~AdADl@r@wARbA\\Pn@iAbA`@ROrAVzA_@d@J|@Xp@S`AmA\\}@~AbC]Fx@j@l@ObAOLpAlA|HwFpHgBn@uAxBWd@mArG{DdIqJtFwAtC}BxAGhBmAhDGfCyA~BK~@uA}@}Dt@wAvD]lArAjEVzC{BdBPfBi@z@f@nA[zA`BzCi@DiAxBNPm@hBTnBtCtBA@_Kw@s@h@oBj@q@rDEbBu@XxCdGmOVh@gB|J`@fAjEWhAoB?`Fh@d@\\oBvA]tBmBjBkEtAr@lBO`ChGvAz@g@xAPrAfCr@vAgA?pBr@}@z@kDz@]|Ar@p@rFp@@t@eBWd@Nz@w@xBVVq@fA`@|@yAj@v@v@kABf@^UL_CFhAnACrAxAjCjDA~ClDr@zBKlAg@xCl@PyAVqEjDkD`@_@`ADpAwAbD[O|AdEk@bBtAlEQxGtAnDbDNpD{Aa@`@b@NSp@dKbAjBaBjBYd@_ArBB|BhAdC}DbG_BlAf@xBYjA_Cz@IdAeCvAy@`@{AdCqCxBUrCn@AdAoBbC~@bB`Bt@xEa@fBsAn@{BIw@h@KEk@l@I?g@v@FAe@lCiA\\y@dGwA?iA|AFJ_@]q@NqBjAxB`BP`CxB?{AhCqBQcA`Aq@FwBs@a@z@p@YbAPZ_Ap@PjAkC~AEfBiBsByBQgAiCDhDA\\yAGO`@XX_Et@aGnD[lAu@FDf@{@BA|A[Cb@Pk@nAsBlAsEn@gCuAc@}@v@G`AmDuC_AkAN}AbA}@x@c@bCcAXwBhC?t@c@Uo@~AgDn@eIh@oCfEoCgAmBVKo@mCUiCkBe@DHd@gAjAwDwK{BsCsF}A{CjB^mAwAmC?}@^J^uBf@U^sDxFqArCmCrADu@k@l@eEq@mCyCmDwDLqAiCMaBw@eAnCK_@{@fAHe@kArASg@y@`@sAYSx@gA^eCe@AsA~A[y@j@qJgGt@u@jBB`AgAnB}@F_BuA@{CeDgEc@aBiEm@yB`EmBlBkAVm@pBe@wBRiC_BjBuDZc@q@bBsKUc@kGnOQ}C}G`Ao@p@D~@&key=AIzaSyAhdVJIK052gJzuSxvUuhKZPNgXdyaA9ig

// Simple, first implementation.  Just list all of the activities since Jan 1, 2021
// curl -X GET "https://www.strava.com/api/v3/athlete/activities?after=1609459200&per_page=30" -H "accept: application/json" -H "authorization: Bearer 0275e53d4c133d20f8fd628954b031faab7f9cfe"
//
// Check if the authorization token has expired
//
class ImportActivitiesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    firebase_storage.FirebaseStorage storage =
        firebase_storage.FirebaseStorage.instance;

    // firebase_storage.StorageReference ref = firebase_storage.FirebaseStorage.instance.ref('/notes.txt');

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: FlatButton(
          child: Text('Select files'),
          onPressed: () {
            pickFiles();
          },
        ),
      ),
    );
  }

  Future<void> pickFiles() async {
    // TODO: support other formats when we can (tcx, fit?)
    FilePickerResult result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gpx'], withData: true);

    if(result != null) {
      print(result.names.toString());
      print(result.files.first.name.toString());
      var url = await uploadFile(result.files.first.bytes, "test.gpx");
      print('uploaded to $url');
      // File file = File(result.files.first.path);
      // print(file);
      // if (file != null) {
      //   await uploadFile(file);
      // }
      // Directory appDocDir = await getApplicationDocumentsDirectory();
    }
  }

  Future<String> uploadFile(Uint8List data, String filename) async {
    StorageReference ref = FirebaseStorage.instance
        .ref()
        .child('testupload/${filename}'); // ${Path.basename(file.path)}');

    var uploadTask = ref.putData(data);
    StorageTaskSnapshot taskSnapshot = await uploadTask.onComplete;

    return 'bogus!';

    // String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    // return downloadUrl;


    // StorageReference storageReference = FirebaseStorage.instance
    //     .ref()
    //     .child('testupload/${filename}'); // ${Path.basename(file.path)}');
    // try {
    //   // StorageReference _storage = storage().ref('002test');

    // StorageMetadata.UploadMetadata(contentType: 'image/png')
    // StorageUploadTask uploadTask = storageReference.putData(bytes);
    // uploadTask.onComplete
    //   var imageUri = await uploadTaskSnapshot.ref.getDownloadURL();
    //   url = imageUri.toString();
    // } catch (e) {
    //   print(e);
    // }



    // StorageReference storageReference = FirebaseStorage.instance
    //     .ref()
    //     .child('testupload/${filename}'); // ${Path.basename(file.path)}');
    // // StorageUploadTask uploadTask = storageReference.putFile(file);
    // StorageUploadTask uploadTask = storageReference.putData(data);
    // await uploadTask.onComplete;
    // print('File Uploaded');
    // String returnURL;
    // await storageReference.getDownloadURL().then((fileURL) {
    //   returnURL =  fileURL;
    // });
    // return returnURL;
  }
}
