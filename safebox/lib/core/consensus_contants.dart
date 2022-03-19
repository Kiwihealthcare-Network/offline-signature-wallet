import 'package:safebox/util/util.dart';

class ConsensusConstants {
  ///# Forks of chia should change this value to provide replay attack protection. This is set to mainnet genesis chall
  static final AGG_SIG_ME_ADDITIONAL_DATA = Util.toBytes(
      'ccd5bb71183532bff220ba46c268991a3ff07eb358e8255a65c30a2dce0e5fbb');

  static final AGG_SIG_ME_ADDITIONAL_DATA_KIWI = Util.toBytes(
      '6f374f378e53e280d72958122d9227a545b61a436ef20e7b0c09465d489e1de9');

  ///# Max block cost in clvm cost units
  static final MAX_BLOCK_COST_CLVM = BigInt.from(11000000000);
}
