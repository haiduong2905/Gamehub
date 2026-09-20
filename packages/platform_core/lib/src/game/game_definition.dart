import '../protocol/ids.dart';
import 'game_result.dart';

/// Luat cua mot game. Day la thu duy nhat mot game moi phai implement.
///
/// KHONG duoc chua: socket, IP, discovery, Widget, hay bat ky thu gi
/// lien quan den ket noi hoac giao dien. Toan bo file nay la pure Dart.
///
/// [S] la kieu game state, [A] la kieu mot nuoc di.
abstract class GameDefinition<S, A> {
  const GameDefinition();

  GameId get id;
  String get name;
  int get minPlayers;
  int get maxPlayers;

  /// Tao state ban dau. [players] da duoc xep theo dung thu tu luot di.
  ///
  /// [seed] do host sinh ra va phat cho tat ca client, nen game co yeu to
  /// ngau nhien (chia bai, xao quan) van cho ra ket qua tat dinh o moi may.
  S createInitialState(
    List<PlayerId> players, {
    required int seed,
    Map<String, dynamic> options = const {},
  });

  /// Kiem tra nuoc di co hop le khong. KHONG duoc thay doi [state].
  ValidationResult validate(S state, PlayerId actor, A action);

  /// Ap dung nuoc di. Chi duoc goi sau khi [validate] tra ve hop le.
  /// Phai tra ve state moi, khong sua [state] cu tai cho.
  S apply(S state, PlayerId actor, A action);

  /// Nhung nguoi dang den luot di.
  ///
  /// Platform can biet dieu nay de hien UI chung ("Luot cua ban", dem gio)
  /// ma khong phai hieu luat game. Game tu khai bao, platform khong suy ra.
  /// Tra ve rong khi van dau da ket thuc.
  List<PlayerId> currentActors(S state);

  bool isFinished(S state);

  /// Chi duoc goi khi [isFinished] tra ve true.
  GameResult getResult(S state);

  /// Phan cua state ma [viewer] duoc phep nhin thay.
  ///
  /// Mac dinh la toan bo state, dung cho moi game thong tin day du
  /// (co caro, co vua, connect-four). Game co thong tin an (bai tren tay)
  /// override ham nay de che bai cua nguoi khac truoc khi host gui di.
  S viewFor(PlayerId viewer, S state) => state;

  Map<String, dynamic> encodeState(S state);
  S decodeState(Map<String, dynamic> json);

  Map<String, dynamic> encodeAction(A action);
  A decodeAction(Map<String, dynamic> json);
}
