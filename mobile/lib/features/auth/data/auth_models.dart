import 'package:equatable/equatable.dart';

class TokenPair extends Equatable {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn];
}

class UserProfile extends Equatable {
  const UserProfile({required this.id, required this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
    );
  }

  final String id;
  final String email;

  @override
  List<Object?> get props => [id, email];
}
