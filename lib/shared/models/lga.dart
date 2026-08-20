class Lga {
  const Lga({required this.id, required this.state, required this.name});

  final int id;
  final String state;
  final String name;

  factory Lga.fromJson(Map<String, dynamic> json) {
    return Lga(
      id: json['id'] as int,
      state: json['state'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => '$name, $state';
}
