class User {
  final int id;
  final String? birthDate;
  final String? profilePicture;
  final String name;
  final String? password;
  final String? email;

  User({
    required this.id,
    this.birthDate,
    this.profilePicture,
    required this.name,
    this.password,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final combinedName = "${json['first_name'] ?? ''} ${json['last_name'] ?? ''}".trim();
    final explicitName = json['name']?.toString().trim();
    final resolvedName = (explicitName != null && explicitName.isNotEmpty)
        ? explicitName
        : (combinedName.isNotEmpty ? combinedName : 'User');

    return User(
      id: json['id'] as int? ?? 0,
      name: resolvedName,
      email: json['email'] as String?,
      profilePicture: json['profile_picture'] as String?,
      birthDate: json['birth_date'] as String?, 
      password: null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'birth_date': birthDate,
      'profile_picture': profilePicture,
      'name': name,
      'email': email,
    };
    if (password != null) {
      data['password'] = password!;
    }
    return data;
  }

  User copyWith({
    int? id,
    String? birthDate,
    String? profilePicture,
    String? name,
    String? password,
    String? email,
  }) {
    return User(
      id: id ?? this.id,
      birthDate: birthDate ?? this.birthDate,
      profilePicture: profilePicture ?? this.profilePicture,
      name: name ?? this.name,
      password: password ?? this.password,
      email: email ?? this.email,
    );
  }
}
