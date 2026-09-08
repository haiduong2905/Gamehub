import '../protocol/ids.dart';

/// Ket cuc cua mot van dau.
enum GameOutcome {
  /// Co nguoi thang.
  win,

  /// Hoa.
  draw,

  /// Van dau khong ket thuc binh thuong (nguoi choi thoat / mat ket noi qua lau).
  abandoned,
}

/// Ket qua cuoi cung cua mot van dau. Chi host duoc phep tao ra gia tri nay.
class GameResult {
  const GameResult({
    required this.outcome,
    this.winners = const [],
    this.reason,
  });

  factory GameResult.win(PlayerId winner, {String? reason}) =>
      GameResult(outcome: GameOutcome.win, winners: [winner], reason: reason);

  factory GameResult.winners(List<PlayerId> winners, {String? reason}) =>
      GameResult(outcome: GameOutcome.win, winners: winners, reason: reason);

  const GameResult.draw({this.reason})
      : outcome = GameOutcome.draw,
        winners = const [];

  /// Van dau bi bo do: nguoi choi roi phong va khong quay lai kip.
  const GameResult.abandoned({this.reason})
      : outcome = GameOutcome.abandoned,
        winners = const [];

  final GameOutcome outcome;

  /// Nguoi thang. Rong khi hoa hoac bo do.
  final List<PlayerId> winners;

  /// Ma ly do doc duoc cho UI, vi du 'OPPONENT_LEFT'.
  final String? reason;

  bool get isWin => outcome == GameOutcome.win;
  bool get isDraw => outcome == GameOutcome.draw;
  bool get isAbandoned => outcome == GameOutcome.abandoned;

  Map<String, dynamic> toJson() => {
        'outcome': outcome.name,
        if (winners.isNotEmpty) 'winners': winners,
        if (reason != null) 'reason': reason,
      };

  static GameResult fromJson(Map<String, dynamic> json) => GameResult(
        outcome: GameOutcome.values.firstWhere(
          (o) => o.name == json['outcome'],
          orElse: () => GameOutcome.abandoned,
        ),
        winners: (json['winners'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic e) => e as String)
            .toList(growable: false),
        reason: json['reason'] as String?,
      );

  @override
  String toString() =>
      'GameResult($outcome, winners: $winners, reason: $reason)';
}

/// Ket qua kiem tra mot nuoc di truoc khi ap dung.
class ValidationResult {
  const ValidationResult.valid()
      : isValid = true,
        code = null,
        message = null;

  const ValidationResult.invalid(this.code, [this.message]) : isValid = false;

  final bool isValid;

  /// Ma loi on dinh de UI dich ra tieng Viet, vi du 'NOT_YOUR_TURN'.
  final String? code;
  final String? message;

  @override
  String toString() => isValid ? 'valid' : 'invalid($code)';
}
