import 'package:intl/intl.dart';

class TimeEntry {
  String id;
  String job;
  DateTime start;
  DateTime? end;

  TimeEntry(this.id, this.job, this.start, this.end);

  Duration get duration => end?.difference(start) ?? Duration.zero;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job': job,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
    };
  }

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      map['id'],
      map['job'],
      DateTime.parse(map['start']),
      map['end'] != null ? DateTime.parse(map['end']) : null,
    );
  }

  String get formattedStart => DateFormat('yyyy-MM-dd hh:mma').format(start);
  String get formattedEnd =>
      end != null ? DateFormat('yyyy-MM-dd hh:mma').format(end!) : 'N/A';
  String get formattedDuration => duration.toString();
}
