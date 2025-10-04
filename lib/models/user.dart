class User {
  final String id;
  final String username;
  final String email;
  final int? age;
  final double? height;
  final double? weight;
  final int? dailySteps;
  final int? dailyCalories;
  final String? avatarUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
     this.age,
     this.height,
     this.weight,
     this.dailySteps,
     this.dailyCalories,
    this.avatarUrl,
  });

factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      age: json['age'],
      height: json['height'] != null ? (json['height'] as num).toDouble() : null,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      dailySteps: json['dailySteps'],
      dailyCalories: json['dailyCalories'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      // additional fields
      'age': age,
      'height': height,
      'weight': weight,
      'dailySteps': dailySteps,
      'dailyCalories': dailyCalories,
      'avatarUrl': avatarUrl,
    };
  }
}
