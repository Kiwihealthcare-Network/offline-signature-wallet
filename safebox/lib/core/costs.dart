class Cost {
  static final INFINITE_COST = BigInt.parse('7FFFFFFFFFFFFFFF', radix: 16);

  static final PATH_LOOKUP_BASE_COST = BigInt.from(40);
  static final PATH_LOOKUP_COST_PER_LEG = BigInt.from(4);
  static final PATH_LOOKUP_COST_PER_ZERO_BYTE = BigInt.from(4);

  static final ARITH_BASE_COST = BigInt.from(99);
  static final ARITH_COST_PER_ARG = BigInt.from(320);
  static final ARITH_COST_PER_BYTE = BigInt.from(3);

  static final MUL_BASE_COST = BigInt.from(92);
  static final MUL_COST_PER_OP = BigInt.from(885);
  static final MUL_LINEAR_COST_PER_BYTE = BigInt.from(6);
  static final MUL_SQUARE_COST_PER_BYTE_DIVIDER = BigInt.from(128);

  static final CONCAT_BASE_COST = BigInt.from(142);
  static final CONCAT_COST_PER_ARG = BigInt.from(135);
  static final CONCAT_COST_PER_BYTE = BigInt.from(3);

  static final IF_COST = BigInt.from(33);
  static final CONS_COST = BigInt.from(50);
  static final FIRST_COST = BigInt.from(30);
  static final REST_COST = BigInt.from(30);
  static final LISTP_COST = BigInt.from(19);

  static final EQ_BASE_COST = BigInt.from(117);
  static final EQ_COST_PER_BYTE = BigInt.from(1);

  static final MALLOC_COST_PER_BYTE = BigInt.from(10);

  static final SHA256_BASE_COST = BigInt.from(87);
  static final SHA256_COST_PER_ARG = BigInt.from(134);
  static final SHA256_COST_PER_BYTE = BigInt.from(2);

  static final DIVMOD_BASE_COST = BigInt.from(1116);
  static final DIVMOD_COST_PER_BYTE = BigInt.from(6);

  static final DIV_BASE_COST = BigInt.from(988);
  static final DIV_COST_PER_BYTE = BigInt.from(4);

  static final GR_BASE_COST = BigInt.from(498);
  static final GR_COST_PER_BYTE = BigInt.from(2);

  static final GRS_BASE_COST = BigInt.from(117);
  static final GRS_COST_PER_BYTE = BigInt.from(1);

  static final PUBKEY_BASE_COST = BigInt.from(1325730);
  static final PUBKEY_COST_PER_BYTE = BigInt.from(38);

  static final POINT_ADD_BASE_COST = BigInt.from(101094);
  static final POINT_ADD_COST_PER_ARG = BigInt.from(1343980);

  static final STRLEN_BASE_COST = BigInt.from(173);
  static final STRLEN_COST_PER_BYTE = BigInt.from(1);

  static final LSHIFT_BASE_COST = BigInt.from(277);
  static final LSHIFT_COST_PER_BYTE = BigInt.from(3);

  static final LOG_BASE_COST = BigInt.from(100);
  static final LOG_COST_PER_BYTE = BigInt.from(3);
  static final LOG_COST_PER_ARG = BigInt.from(264);

  static final LOGNOT_BASE_COST = BigInt.from(331);
  static final LOGNOT_COST_PER_BYTE = BigInt.from(3);

  static final BOOL_BASE_COST = BigInt.from(200);
  static final BOOL_COST_PER_ARG = BigInt.from(300);

  static final APPLY_COST = BigInt.from(90);
  static final QUOTE_COST = BigInt.from(20);
}
