import 'dart:convert';

import 'package:safebox/clvm/program.dart';
import 'package:safebox/clvm/puzzle.dart';
import 'package:safebox/clvm/serialized_program.dart';
import 'package:safebox/core/bech32.dart';
import 'package:safebox/core/consensus_contants.dart';
import 'package:safebox/core/ec.dart';
import 'package:safebox/util/condition_tool.dart';
import 'package:safebox/util/puzzle_util.dart';
import 'package:safebox/util/util.dart';
import 'package:safebox/wallet/private_key.dart';

class Transaction {
  static SpendBundle generateSignedTransaction({
    required BigInt amount,
    required String from,
    required String to,
    required BigInt fee,
    required PrivateKey privateKey,
    required List<CoinUnspent> utxos,
  }) {
    /// """
    /// Use this to generate transaction.
    /// Note: this must be called under a wallet state manager lock
    /// """
    assert(utxos.isNotEmpty);
    var transaction = _generateUnsignedTransaction(
        amount: amount,
        puzzleHashFrom: Bech32m.decodePuzzleHash(from),
        puzzleHashTo: Bech32m.decodePuzzleHash(to),
        fee: fee,
        utxos: utxos,
        publicKey: privateKey.getPublicKeyPointWallet());
    var secret_key = Puzzle.calculateSyntheticSecretKey(
        privateKey, Puzzle.DEFAULTHIDDENPUZZLEHASH);

    var addittionalData = ConsensusConstants.AGG_SIG_ME_ADDITIONAL_DATA_KIWI;
    if (from.startsWith("tkik")) {
      addittionalData = ConsensusConstants.AGG_SIG_ME_ADDITIONAL_DATA_KIWI;
    } else {
      addittionalData = ConsensusConstants.AGG_SIG_ME_ADDITIONAL_DATA;
    }

    var spendBundle = signCoinSpends(
      coinSpends: transaction,
      privateKey: secret_key,
      additionalData: addittionalData,
      maxCost: ConsensusConstants.MAX_BLOCK_COST_CLVM,
    );
    return spendBundle;
  }

  static List<CoinSpend> _generateUnsignedTransaction({
    required BigInt amount,
    required List<int> puzzleHashTo,
    required List<int> puzzleHashFrom,
    required BigInt fee,
    required List<CoinUnspent> utxos,
    required JacobianPoint publicKey,
  }) {
    /// """
    /// Generates a unsigned transaction in form of List(Puzzle, Solutions)
    /// Note: this must be called under a wallet state manager lock
    /// """
    var totalAmount = amount + fee;
    var selectUtxos = _selectUnspentCoins(
      amount: totalAmount,
      coinUnspents: utxos,
    );
    var spentValue = BigInt.zero;
    for (var _ in selectUtxos) {
      spentValue += _.amount;
    }
    var changeValue = spentValue - totalAmount;
    var primaries = <Map<String, dynamic>>[];
    var messageList = <List<int>>[];
    Announcement? primaryAnnouncementHash;
    var spends = <CoinSpend>[];
    for (var coin in selectUtxos) {
      var puzzle = Puzzle.puzzleForPuzzleHash(publicKey);
      Program solution;
      if (primaryAnnouncementHash == null) {
        if (primaries.isEmpty) {
          primaries.add({'puzzlehash': puzzleHashTo, 'amount': amount});
        } else {
          primaries.add({'puzzlehash': puzzleHashTo, 'amount': amount});
        }
        if (changeValue > BigInt.zero) {
          primaries.add({'puzzlehash': puzzleHashFrom, 'amount': changeValue});
        }
        for (var _ in selectUtxos) {
          messageList.add(_.name);
        }
        for (var primarie in primaries) {
          messageList.add(CoinUnspent(
              parentCoinInfo: coin.name,
              puzzleHash: primarie['puzzlehash'],
              amount: primarie['amount'],
              spent: false,
              timestamp: 0)
              .name);
        }
        var messageData = <int>[];
        for (var _ in messageList) {
          messageData.addAll(_);
        }
        var message = Util.stdHash(messageData);
        solution = _makeSolution(
          primaries: primaries,
          amount: amount,
          fee: fee,
          coinAnnouncements: {message},
        );
        primaryAnnouncementHash =
            Announcement(originInfo: coin.name, message: message);
      } else {
        solution = _makeSolution(
          primaries: [],
          amount: BigInt.zero,
          fee: BigInt.zero,
          coinAnnouncements: {primaryAnnouncementHash.name},
        );
      }
      spends.add(
        CoinSpend(
            coin: coin,
            puzzleReveal: SerializedProgram.fromBytes(puzzle.toBytes()),
            solution: SerializedProgram.fromBytes(solution.toBytes())),
      );
    }
    return spends;
  }

  static List<CoinUnspent> _selectUnspentCoins({
    required BigInt amount,
    required List<CoinUnspent> coinUnspents,
  }) {
    coinUnspents.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var sumValue = BigInt.zero;
    var selectUnspents = <CoinUnspent>[];

    for (var _ in coinUnspents) {
      if (sumValue >= amount && coinUnspents.isNotEmpty) {
        return selectUnspents;
      }
      sumValue += _.amount;
      selectUnspents.add(_);
    }
    if (sumValue >= amount) {
      return selectUnspents;
    } else {
      return <CoinUnspent>[];
    }
  }

  static Program _makeSolution({
    required List<Map<String, dynamic>> primaries,
    required BigInt amount,
    required BigInt fee,
    required Set<List<int>> coinAnnouncements,
  }) {
    var conditionList = [];
    if (primaries.isNotEmpty) {
      for (var primary in primaries) {
        conditionList.add(PuzzleUtil.makeCreateCoinCondition(
          primary['puzzlehash'],
          primary['amount'],
        ));
      }
    }
    if (fee != BigInt.zero) {
      conditionList.add(PuzzleUtil.makeReserveFeeCondition(fee));
    }
    if (coinAnnouncements.isNotEmpty) {
      for (var announcement in coinAnnouncements) {
        conditionList.add(PuzzleUtil.makeCreateCoinAnnouncement(announcement));
      }
    }
    return Puzzle.solutionFoConditions(conditionList);
  }

  static signCoinSpends({
    required List<CoinSpend> coinSpends,
    required PrivateKey privateKey,
    required List<int> additionalData,
    required BigInt maxCost,
  }) {
    var signatures = <JacobianPoint>[];
    var pkList = <JacobianPoint>[];
    var msgList = <List<int>>[];
    for (var coinSpend in coinSpends) {
      //# Get AGG_SIG conditions
      var conditionDict = ConditionTool.conditionsDictForSolution(
        coinSpend.puzzleReveal,
        coinSpend.solution,
        maxCost,
      );
      if (conditionDict.elementAt(0) == null) {
        throw Exception('Error,');
      }
      for (var data in ConditionTool.pkmPairsForConditionsDict(
          conditionDict.elementAt(0), coinSpend.coin.name, additionalData)) {
        pkList.add(data.elementAt(0));
        msgList.add(data.elementAt(1));
        var signature = AugSchemeMPL.sign(privateKey, data.elementAt(1));
        print(signature.x.runtimeType.toString());
        signatures.add(signature);
      }
    }
    // Aggregate signatures
    var aggsig = AugSchemeMPL.aggregate(signatures);
    return SpendBundle(coinSpends: coinSpends, aggregatedSignature: aggsig);
  }
}

class CoinUnspent {
  ///"""
  ///  This structure is used in the body for the reward and fees genesis coins.
  ///  """
  final List<int> parentCoinInfo;
  final List<int> puzzleHash;
  final BigInt amount;
  final bool spent;
  final int timestamp;
  CoinUnspent({
    required this.parentCoinInfo,
    required this.puzzleHash,
    required this.amount,
    required this.spent,
    required this.timestamp,
  });

  List<int> getHash() {
    return Util.stdHash(parentCoinInfo + puzzleHash + Util.intToByte(amount));
  }

  List<int> get name => getHash();

  String get nameHex => Util.toHex(name);

  List<dynamic> get asList => [parentCoinInfo, puzzleHash, amount];

  @override
  String toString() {
    return 'CoinUnspent(parentCoinInfo: $parentCoinInfo, puzzleHash: $puzzleHash, amount: $amount, spent: $spent, timestamp: $timestamp)';
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount.toInt(),
      'parent_coin_info': '0x' + Util.toHex(parentCoinInfo),
      'puzzle_hash': '0x' + Util.toHex(puzzleHash),
    };
  }

  String toJson() => json.encode(toMap());

  CoinUnspent.fromJson(Map<String, dynamic> json)
      : amount = BigInt.parse(json['amount'],radix: 10),
        parentCoinInfo = Util.toBytes(json['parent_coin_info']),
        puzzleHash = Util.toBytes(json['puzzle_hash']),
        spent = false,
        timestamp = 0;
}

class Announcement {
  final List<int> originInfo;
  final List<int> message;
  Announcement({
    required this.originInfo,
    required this.message,
  });

  List<int> get name => getHash();

  List<int> getHash() {
    return Util.stdHash(originInfo + message);
  }

  @override
  String toString() =>
      'Announcement(originInfo: $originInfo, message: $message)';
}

class CoinSpend {
  final CoinUnspent coin;
  final SerializedProgram puzzleReveal;
  final SerializedProgram solution;
  CoinSpend({
    required this.coin,
    required this.puzzleReveal,
    required this.solution,
  });

  @override
  String toString() =>
      'CoinSpend(coin: $coin, puzzleReveal: $puzzleReveal, solution: $solution)';

  Map<String, dynamic> toMap() {
    return {
      'coin': coin.toMap(),
      'puzzle_reveal': '0x' + puzzleReveal.toHex(),
      'solution': '0x' + solution.toHex(),
    };
  }

  String toJson() => json.encode(toMap());
}

class SpendBundle {
  /// """
  /// This is a list of coins being spent along with their solution programs, and a single
  /// aggregated signature. This is the object that most closely corresponds to a bitcoin
  /// transaction (although because of non-interactive signature aggregation, the boundaries
  /// between transactions are more flexible than in bitcoin).
  /// """
  final List<CoinSpend> coinSpends;
  final JacobianPoint aggregatedSignature;
  SpendBundle({
    required this.coinSpends,
    required this.aggregatedSignature,
  });

  @override
  String toString() =>
      'SpendBundle(coinSpends: $coinSpends, aggregatedSignature: $aggregatedSignature)';

  Map<String, dynamic> toMap() {
    return {
      'spend_bundle': {
        'aggregated_signature': '0x' + aggregatedSignature.toHex(),
        'coin_solutions': coinSpends.map((x) => x.toMap()).toList(),
      }
    };
  }

  String toJson() => json.encode(toMap());
}
