class OfflineLease {
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Duration initialMonotonic;

  OfflineLease({
    required this.issuedAt,
    required this.expiresAt,
    required this.initialMonotonic,
  });

  bool canWrite(DateTime wall, Duration currentMonotonic) {
    // 1. Clock rollback detection: wall clock must not be rewound before issuedAt
    if (wall.isBefore(issuedAt)) {
      return false;
    }

    // 2. Monotonic clock must not have gone backward
    if (currentMonotonic < initialMonotonic) {
      return false;
    }

    // 3. Wall clock must not exceed expiresAt (24h window)
    if (wall.isAfter(expiresAt)) {
      return false;
    }

    // 4. Elapsed monotonic duration must not exceed lease window
    final elapsedMonotonic = currentMonotonic - initialMonotonic;
    final totalAllowedDuration = expiresAt.difference(issuedAt);
    if (elapsedMonotonic > totalAllowedDuration) {
      return false;
    }

    return true;
  }
}
