import '../api/api_failure.dart';

enum RetryAction { stopBlockedAuth, needsReview, retryAfter, retryLater }

class RetryDecision {
  final RetryAction action;
  final Duration? delay;

  const RetryDecision._(this.action, [this.delay]);

  factory RetryDecision.stopBlockedAuth() =>
      const RetryDecision._(RetryAction.stopBlockedAuth);

  factory RetryDecision.needsReview() =>
      const RetryDecision._(RetryAction.needsReview);

  factory RetryDecision.retryAfter(Duration delay) =>
      RetryDecision._(RetryAction.retryAfter, delay);

  factory RetryDecision.retryLater(Duration delay) =>
      RetryDecision._(RetryAction.retryLater, delay);
}

class RetryPolicy {
  final int maxSessionAttempts;

  const RetryPolicy({this.maxSessionAttempts = 5});

  RetryDecision next(ApiFailure failure, int attempt) {
    if (failure.status == 401 || failure.status == 403) {
      return RetryDecision.stopBlockedAuth();
    }

    if (failure.status == 409 || failure.status == 422) {
      return RetryDecision.needsReview();
    }

    if (failure.status == 429) {
      final seconds = failure.retryAfter ?? 30;
      return RetryDecision.retryAfter(Duration(seconds: seconds));
    }

    if (attempt >= maxSessionAttempts) {
      return RetryDecision.needsReview();
    }

    final delaySeconds = (2 << (attempt - 1)).clamp(2, 300);
    return RetryDecision.retryLater(Duration(seconds: delaySeconds));
  }
}
