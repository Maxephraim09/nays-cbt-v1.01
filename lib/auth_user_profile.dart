import 'package:firebase_auth/firebase_auth.dart';

class AuthUserProfile {
  const AuthUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.photoUrl,
    required this.providerIds,
    required this.createdAt,
    required this.emailVerified,
    this.naysStudentId,
    this.isLocalAccount = false,
  });

  factory AuthUserProfile.fromFirebaseUser(User user) => AuthUserProfile(
    uid: user.uid,
    displayName: user.displayName ?? '',
    email: user.email ?? '',
    phoneNumber: user.phoneNumber,
    photoUrl: user.photoURL,
    providerIds: user.providerData
        .map((provider) => provider.providerId)
        .toList(),
    createdAt: _parseCreationTime(user.metadata.creationTime),
    emailVerified: user.emailVerified,
  );

  final String uid;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final List<String> providerIds;
  final DateTime? createdAt;
  final bool emailVerified;

  // Firebase identity is not proof of NAYS membership or exam eligibility.
  final String? naysStudentId;
  final bool isLocalAccount;
  String get naysMembershipStatus => 'NAYS membership not linked';
  bool get isEligibleForOfficialExams => false;
}

DateTime? _parseCreationTime(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
