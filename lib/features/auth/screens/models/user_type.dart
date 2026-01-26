enum UserType {
  alumni,
  school,
}

extension UserTypeX on UserType {
  String get label {
    switch (this) {
      case UserType.alumni:
        return 'Alumni';
      case UserType.school:
        return 'School';
    }
  }
}
