import 'package:flutter/material.dart';
import 'package:osmp_project/settings_page.dart';
import 'package:osmp_project/overall_status_widget.dart';
import 'package:osmp_project/trail_progress_list_widget.dart';

enum TrailStatus { inProgress, completed }

class TrailsProgressWidget extends StatefulWidget {
  TrailsProgressWidget(this.settingsOptions);

  final SettingsOptions settingsOptions;

  @override
  _TrailsProgressState createState() => _TrailsProgressState(settingsOptions);
}

class _TrailsProgressState extends State<TrailsProgressWidget> {
  final SettingsOptions settingsOptions;
  String _progressFilterValue = 'All';

  _TrailsProgressState(this.settingsOptions);

  void _handleProgressFilterChanged(String progressFilter) {
    setState(() {
      _progressFilterValue = progressFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        OverallStatusWidget(settingsOptions),
        FilterWidget(
          progressFilterValue: _progressFilterValue,
          onChanged: _handleProgressFilterChanged,
        ),
        Expanded(
            child: TrailProgressListWidget(
          settingsOptions: settingsOptions,
          progressFilterValue: _progressFilterValue,
        ))
      ],
    );
  }
}

class FilterWidget extends StatelessWidget {
  FilterWidget(
      {Key key, this.progressFilterValue: 'All', @required this.onChanged})
      : super(key: key);

  final String progressFilterValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 0.0),
      child: Card(
        child: Padding(
          padding:
              EdgeInsets.only(top: 6.0, left: 6.0, right: 6.0, bottom: 6.0),
          child: ExpansionTile(
            title: Text('Filter'),
            children: <Widget>[
              ProgressStatusFilterWidget(
                  progressFilterValue: progressFilterValue,
                  onChanged: onChanged),
              // Text('Birth of the Sun'),
              // Text('Earth is Born'),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressStatusFilterWidget extends StatelessWidget {
  ProgressStatusFilterWidget(
      {Key key, this.progressFilterValue: 'All', @required this.onChanged})
      : super(key: key);

  final String progressFilterValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding:
            EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 0.0),
        child: Row(children: [
          DropdownButton<String>(
            value: progressFilterValue,
            icon: Icon(Icons.arrow_downward),
            iconSize: 24,
            elevation: 16,
            style: TextStyle(color: Colors.deepPurple),
            underline: Container(
              height: 2,
              color: Colors.deepPurpleAccent,
            ),
            onChanged: (String newValue) {
              onChanged(newValue);
            },
            items: <String>['All', 'In progress', 'Completed']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          )
        ]));
  }
}
