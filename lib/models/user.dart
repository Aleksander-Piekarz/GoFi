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
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      age: json['age'] != null ? int.tryParse(json['age'].toString()) : null,
      height: json['height'] != null ? double.tryParse(json['height'].toString()) : null,
      weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
      dailySteps: json['dailySteps'] != null ? int.tryParse(json['dailySteps'].toString()) : null,
      dailyCalories: json['dailyCalories'] != null ? int.tryParse(json['dailyCalories'].toString()) : null,
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'age': age,
      'height': height,
      'weight': weight,
      'dailySteps': dailySteps,
      'dailyCalories': dailyCalories,
      'avatarUrl': avatarUrl,
    };
  }
}