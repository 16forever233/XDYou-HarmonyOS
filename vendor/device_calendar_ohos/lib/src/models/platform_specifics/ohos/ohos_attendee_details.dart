import '../../../common/error_messages.dart';
import 'ohos_attendee_role.dart';

class OhosAttendeeDetails {
  OhosAttendanceRole? ohosRole;

  OhosAttendeeDetails({this.ohosRole});

  OhosAttendeeDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError(ErrorMessages.fromJsonMapIsNull);
    }

    if (json['ohosRole'] != null && json['ohosRole'] is int) {
      ohosRole =
      OhosAttendanceRole.values[json['ohosRole']];
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'ohosRole': ohosRole?.index};
  }
}