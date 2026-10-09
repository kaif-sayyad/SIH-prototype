class TradeOutcome {
  final String trade;
  final String provider;
  final String location;
  final double placementRate;
  final int avgEarnings;
  final int nsqfLevel;
  final int durationMonths;
  final int trainingCost;
  final String minEducation;
  final String jobRoles;
  final String progression;
  final String furtherEducation;
  final String source;
  final String dataDate;

  TradeOutcome({
    required this.trade,
    required this.provider,
    required this.location,
    required this.placementRate,
    required this.avgEarnings,
    required this.nsqfLevel,
    required this.durationMonths,
    required this.trainingCost,
    required this.minEducation,
    required this.jobRoles,
    required this.progression,
    required this.furtherEducation,
    required this.source,
    required this.dataDate,
  });

  factory TradeOutcome.fromCsvRow(List<dynamic> row) {
    return TradeOutcome(
      trade: row[0].toString().trim(),
      provider: row[1].toString().trim(),
      location: row[2].toString().trim(),
      placementRate: double.tryParse(row[3].toString()) ?? 0.0,
      avgEarnings: int.tryParse(row[4].toString()) ?? 0,
      nsqfLevel: int.tryParse(row[5].toString()) ?? 4,
      durationMonths: int.tryParse(row[6].toString()) ?? 12,
      trainingCost: int.tryParse(row[7].toString()) ?? 0,
      minEducation: row[8].toString().trim(),
      jobRoles: row[9].toString().trim(),
      progression: row[10].toString().trim(),
      furtherEducation: row[11].toString().trim(),
      source: row[12].toString().trim(),
      dataDate: row[13].toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'trade': trade,
    'provider': provider,
    'location': location,
    'placementRate': placementRate,
    'avgEarnings': avgEarnings,
    'nsqfLevel': nsqfLevel,
    'durationMonths': durationMonths,
    'trainingCost': trainingCost,
    'minEducation': minEducation,
    'jobRoles': jobRoles,
    'progression': progression,
    'furtherEducation': furtherEducation,
    'source': source,
    'dataDate': dataDate,
  };
}
