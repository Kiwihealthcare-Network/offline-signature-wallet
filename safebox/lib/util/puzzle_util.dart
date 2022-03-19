import '../core/condition_opcode.dart';

class PuzzleUtil {
  static List<dynamic> makeCreateCoinCondition(
    List<int> puzzleHash,
    BigInt amount,
  ) {
    return [ConditionOpcode.CREATE_COIN, puzzleHash, amount];
  }

  static List<dynamic> makeReserveFeeCondition(BigInt fee) {
    return [ConditionOpcode.RESERVE_FEE, fee];
  }

  static List<dynamic> makeCreateCoinAnnouncement(List<int> message) {
    return [ConditionOpcode.CREATE_COIN_ANNOUNCEMENT, message];
  }
}
