import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boulder Trail Challenge Status',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Boulder Trail Challenge Status')),
      body: _mainScreen(context),
    );
  }

  Widget _mainScreen(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSummary(context),
            Expanded(child: _buildTodo(context))
          ],
        ));
  }

  Widget _buildSummary(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: Firestore.instance.collection('athletes').document("dkhawk@gmail.com").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _buildStatus(context, snapshot.data);
      },
    );
  }

  Widget _buildTodo(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('athletes').document("dkhawk@gmail.com")
          .collection("trailStats")
          .where("percentDone", isLessThan: 0.98)
          .orderBy("percentDone", descending: true)
          // .orderBy("name")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return _buildTodoList(context, snapshot.data.documents);
      },
    );
  }

  Widget _buildTodoList(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((data) => _buildTodoListItem(context, data)).toList(),
    );
  }

  Widget _buildStatus(BuildContext context, DocumentSnapshot data) {
    print(data["overallStats"]["percentDone"] * 100);
    return Text("Overall completion: " + (data["overallStats"]["percentDone"] * 100).toStringAsFixed(2) + "%");
  }

  Widget _buildTodoListItem(BuildContext context, DocumentSnapshot data) {
    final trail = TrailSummary.fromSnapshot(data);

    return Padding(
      key: ValueKey(trail.trailId),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: ListTile(
          title: Text(trail.name + " (" + trail.trailId + ")"),
          trailing: Text((trail.percentDone * 100).toStringAsFixed(2) + "%"),
          // onTap: () => record.reference.updateData({'votes': FieldValue.increment(1)})
        ),
      ),
    );
  }
}

class TrailSummary {
  final String trailId;
  final String name;
  final int length;
  final int completedDistance;
  final double percentDone;
  final DocumentReference reference;

  // completed
  // remaining

  TrailSummary.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['length'] != null),
        assert(map['completedDistance'] != null),
        assert(map['percentDone'] != null),
        trailId = reference.documentID,
        name = map['name'],
        length = map['length'],
        completedDistance = map['completedDistance'],
        percentDone = map['percentDone'];

  TrailSummary.fromSnapshot(DocumentSnapshot snapshot)
    : this.fromMap(snapshot.data, reference: snapshot.reference);
}

class CompletedSegment {
  final String activityId;
  final int length;
  final String segmentId;
  final String trailId;
  final String trailName;
  final DocumentReference reference;

  CompletedSegment.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['activityId'] != null),
        assert(map['length'] != null),
        assert(map['segmentId'] != null),
        assert(map['trailId'] != null),
        assert(map['trailName'] != null),
        activityId = map['activityId'],
        length = map['length'],
        segmentId = map['segmentId'],
        trailId = map['trailId'],
        trailName = map['trailName'];

  CompletedSegment.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Record<$trailName:$segmentId>";
}

class Record {
  final String name;
  final String stravaId;
  final int completedSegments;
  final DocumentReference reference;

  Record.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['name'] != null),
        assert(map['stravaId'] != null),
        assert(map['completedSegments'] != null),
        name = map['name'],
        stravaId = map['stravaId'],
        completedSegments = map['completedSegments'];

  Record.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Record<$name:$stravaId>";
}
