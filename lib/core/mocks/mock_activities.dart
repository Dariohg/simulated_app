class ActivityOption {
  final int externalActivityId;
  final String title;
  final String? subtitle;
  final String? content;
  final String activityType;

  const ActivityOption({
    required this.externalActivityId,
    required this.title,
    this.subtitle,
    this.content,
    required this.activityType,
  });
}

class MockActivities {
  static const List<ActivityOption> list = [
    ActivityOption(
      externalActivityId: 501,
      title: "Lectura Rapida",
      subtitle: "Lee el siguiente texto en voz alta",
      content: "El veloz murcielago hindu comia feliz cardillo y kiwi...",
      activityType: "LECTURA",
    ),
    ActivityOption(
      externalActivityId: 502,
      title: "Calculo Mental",
      subtitle: "Resuelve las operaciones sin usar papel",
      content: "25 + 15 * 2 = ?",
      activityType: "LOGICA",
    ),
    ActivityOption(
      externalActivityId: 503,
      title: "Enfoque Visual",
      subtitle: "Sigue el punto rojo con la mirada",
      content: null,
      activityType: "ATENCION",
    ),
  ];
}