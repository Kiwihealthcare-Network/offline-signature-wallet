import 'package:safebox/util/util.dart';

class ConditionOpcode {
  static final CREATE_COIN = Util.toBytes(51);
  static final RESERVE_FEE = Util.toBytes(52);
  static final CREATE_COIN_ANNOUNCEMENT = Util.toBytes(60);
  static final AGG_SIG_UNSAFE = Util.toBytes(49);
  static final AGG_SIG_ME = Util.toBytes(50);
}
