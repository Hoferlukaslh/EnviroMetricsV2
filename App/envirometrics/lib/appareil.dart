class Appareil {
  final int id;
  final String nom;

  Appareil({required this.id, required this.nom});

  factory Appareil.fromJson(Map<String, dynamic> json) {
    return Appareil(
      id: json['id'],
      nom: json['nom'],
    );
  }
}