/// Game co caro 3x3.
///
/// Package nay chua ca luat choi lan giao dien ban co, nhung tach lam hai
/// tang ro rang:
///
/// * `src/logic/` la PURE DART - khong duoc import Flutter. Do la phan cam
///   vao platform va chay duoc bang test khong can thiet bi.
/// * `src/ui/` la Flutter - chi ve lai state ma host gui xuong.
library;

export 'src/logic/tic_tac_toe.dart';
export 'src/logic/tic_tac_toe_ai.dart';
export 'src/ui/tic_tac_toe_board.dart';
export 'src/ui/tic_tac_toe_local_game.dart';
export 'src/ui/tic_tac_toe_icon.dart';
