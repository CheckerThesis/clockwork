class TimeEntry {
  int? id;
  String job;
  DateTime start;
  DateTime end;
  bool needsSync;
  bool isDeleted;

  TimeEntry({
    this.id,
    required this.job,
    required this.start,
    required this.end,
    this.needsSync = true,
    this.isDeleted = false,
  });

  Duration get duration => end.difference(start);

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json["id"] as int?,
      job: json["job"] as String,
      start: DateTime.parse(json["start"] as String),
      end: DateTime.parse(json["end"] as String),
      needsSync: json["needsSync"] == 1,
      isDeleted: json["isDeleted"] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      "id": id,
      "job": job,
      "start": start.toIso8601String(),
      "end": end.toIso8601String(),
      "duration": duration.inSeconds.toString(),
      "needsSync": needsSync ? 1 : 0,
      "isDeleted": isDeleted ? 1 : 0,
    };
    if (id != null && id != -1) {
      map["id"] = id;
    }
    return map;
  }

  @override
  String toString() {
    return "TimeEntry{id: $id, job: $job, start: $start, end: $end, duration: $duration, needsSync: $needsSync}\n";
  }
}
