enum OhosAttendanceRole {
  Organizer,
  Participant
}

extension OhosAttendanceRoleExtensions on OhosAttendanceRole {
  String _enumToString(OhosAttendanceRole enumValue) {
    return enumValue.toString().split('.').last;
  }

  String get enumToString => _enumToString(this);
}