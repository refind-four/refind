/// Foto zu einem Angebot. Die Datei liegt in der Dateiablage (Konzept 2.1).
class Photo {
  const Photo({required this.id, required this.offerId, required this.url});

  final String id;
  final String offerId;
  final String url;
}
