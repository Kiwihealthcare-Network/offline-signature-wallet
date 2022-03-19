import 'package:safebox/core/ec.dart';
import 'package:safebox/core/fields.dart';
import 'package:safebox/core/hash_to_field.dart';

/// roots of unity, used for computing square roots in Fq2
final rv1 = BigInt.parse(
    '6AF0E0437FF400B6831E36D6BD17FFE48395DABC2D3435E77F76E17009241C5EE67992F72EC05F4C81084FBEDE3CC09',
    radix: 16);

/// distinguished non-square in Fp2 for SWU map
final xi2 = Fq2(EC.q, [BigInt.from(-2), BigInt.from(-1)]);

/// 3-isogenous curve parameters
final Ell2p_b = Fq2(EC.q, [BigInt.from(1012), BigInt.from(1012)]);
final Ell2p_a = Fq2(EC.q, [BigInt.zero, BigInt.from(240)]);

/// eta values, used for computing sqrt(g(X1(t)))
/// For details on how to compute, see ../sage-impl/opt_sswu_g2.sage
final ev1 = BigInt.parse(
    '699BE3B8C6870965E5BF892AD5D2CC7B0E85A117402DFD83B7F4A947E02D978498255A2AAEC0AC627B5AFBDF1BF1C90',
    radix: 16);
final ev2 = BigInt.parse(
    '8157CD83046453F5DD0972B6E3949E4288020B5B8A9CC99CA07E27089A2CE2436D965026ADAD3EF7BABA37F2183E9B5',
    radix: 16);
final ev3 = BigInt.parse(
    'AB1C2FFDD6C253CA155231EB3E71BA044FD562F6F72BC5BAD5EC46A0B7A3B0247CF08CE6C6317F40EDBC653A72DEE17',
    radix: 16);
final ev4 = BigInt.parse(
    'AA404866706722864480885D68AD0CCAC1967C7544B447873CC37E0181271E006DF72162A3D3E0287BF597FBF7F8FC1',
    radix: 16);
final Iterable<Fq2> etas = [
  Fq2(EC.q, [ev1, ev2]),
  Fq2(EC.q, [EC.q - ev2, ev1]),
  Fq2(EC.q, [ev3, ev4]),
  Fq2(EC.q, [EC.q - ev4, ev3]),
];
// final etas = Iterable.generate(_etas.length, (index) => _etas[index]);
final Iterable<Fq2> xnum = [
  Fq2(EC.q, [
    BigInt.parse(
      '5C759507E8E333EBB5B7A9A47D7ED8532C52D39FD3A042A88B58423C50AE15D5C2638E343D9C71C6238AAAAAAAA97D6',
      radix: 16,
    ),
    BigInt.parse(
      '5C759507E8E333EBB5B7A9A47D7ED8532C52D39FD3A042A88B58423C50AE15D5C2638E343D9C71C6238AAAAAAAA97D6',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.zero,
    BigInt.parse(
      '11560BF17BAA99BC32126FCED787C88F984F87ADF7AE0C7F9A208C6B4F20A4181472AAA9CB8D555526A9FFFFFFFFC71A',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.parse(
      '11560BF17BAA99BC32126FCED787C88F984F87ADF7AE0C7F9A208C6B4F20A4181472AAA9CB8D555526A9FFFFFFFFC71E',
      radix: 16,
    ),
    BigInt.parse(
      '8AB05F8BDD54CDE190937E76BC3E447CC27C3D6FBD7063FCD104635A790520C0A395554E5C6AAAA9354FFFFFFFFE38D',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.parse(
      '171D6541FA38CCFAED6DEA691F5FB614CB14B4E7F4E810AA22D6108F142B85757098E38D0F671C7188E2AAAAAAAA5ED1',
      radix: 16,
    ),
    BigInt.zero
  ]),
];

final Iterable<Fq2> xden = [
  Fq2(EC.q, [
    BigInt.zero,
    BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFAA63',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.parse('C', radix: 16),
    BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFAA9F',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [BigInt.one, BigInt.zero]),
];

final Iterable<Fq2> ynum = [
  Fq2(EC.q, [
    BigInt.parse(
      '1530477C7AB4113B59A4C18B076D11930F7DA5D4A07F649BF54439D87D27E500FC8C25EBF8C92F6812CFC71C71C6D706',
      radix: 16,
    ),
    BigInt.parse(
      '1530477C7AB4113B59A4C18B076D11930F7DA5D4A07F649BF54439D87D27E500FC8C25EBF8C92F6812CFC71C71C6D706',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.zero,
    BigInt.parse(
      '5C759507E8E333EBB5B7A9A47D7ED8532C52D39FD3A042A88B58423C50AE15D5C2638E343D9C71C6238AAAAAAAA97BE',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.parse(
        '11560BF17BAA99BC32126FCED787C88F984F87ADF7AE0C7F9A208C6B4F20A4181472AAA9CB8D555526A9FFFFFFFFC71C',
        radix: 16),
    BigInt.parse(
      '8AB05F8BDD54CDE190937E76BC3E447CC27C3D6FBD7063FCD104635A790520C0A395554E5C6AAAA9354FFFFFFFFE38F',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.parse(
        '124C9AD43B6CF79BFBF7043DE3811AD0761B0F37A1E26286B0E977C69AA274524E79097A56DC4BD9E1B371C71C718B10',
        radix: 16),
    BigInt.zero
  ]),
];

final Iterable<Fq2> yden = [
  Fq2(EC.q, [
    BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFA8FB',
      radix: 16,
    ),
    BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFA8FB',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.zero,
    BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFA9D3',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [
    BigInt.parse('12', radix: 16),
    BigInt.parse(
      '1A0111EA397FE69A4B1BA7B6434BACD764774B84F38512BF6730D2A0F6B0F6241EABFFFEB153FFFFB9FEFFFFFFFFAA99',
      radix: 16,
    )
  ]),
  Fq2(EC.q, [BigInt.one, BigInt.zero]),
];

// 3-Isogeny from Ell2' to Ell2
// coefficients for the 3-isogeny map from Ell2' to Ell2

final Iterable<Fq2> rootOfUnity = [
  Fq2(EC.q, [BigInt.one, BigInt.zero]),
  Fq2(EC.q, [BigInt.zero, BigInt.one]),
  Fq2(EC.q, [rv1, rv1]),
  Fq2(EC.q, [rv1, EC.q - rv1]),
];

JacobianPoint optSwu2Map(List<Fq2> args) {
  late Fq2 t;
  late Fq2? t2;
  if (args.length < 2) {
    t = args.first;
    t2 = null;
  } else {
    t = args.first;
    t2 = args.elementAt(1);
  }
  var point = iso3(osswu2Help(t));
  if (t2 != null) {
    var point2 = iso3(osswu2Help(t2));
    point = point + point2;
  }
  return point * EC.hEff;
}

JacobianPoint g2Map(List<int> alpha, List<int>? dst) {
  var data = HashToField.hp2(alpha, 2, dst)
      .map(
        (e) => Fq2(
          EC.q,
          Iterable.generate(e!.length, (index) => e[index]),
        ),
      )
      .toList();
  return optSwu2Map(data);
}

/// Simplified SWU map, optimized and adapted to Ell2'
/// This function maps an element of Fp^2 to the curve Ell2', 3-isogenous to Ell2.
JacobianPoint osswu2Help(Fq2 t) {
  //first, compute X0(t), detecting and handling exceptional case
  var numDenCommon = xi2.pow(2) * t.pow(4) + xi2 * t.pow(2);
  var x0Num = Ell2p_b * (numDenCommon + Fq(EC.q, BigInt.one));
  var x0Den = -Ell2p_a * numDenCommon;
  // ignore: unrelated_type_equality_checks
  x0Den = x0Den == 0 ? Ell2p_a * xi2 : x0Den;
  // compute num and den of g(X0(t))
  var gx0Den = x0Den.pow(3);
  var gx0Num = Ell2p_b * gx0Den;
  gx0Num += Ell2p_a * x0Num * x0Den.pow(2);
  gx0Num += x0Num.pow(3);
  // try taking sqrt of g(X0(t))
  // this uses the trick for combining division and sqrt from Section 5 of
  // Bernstein, Duif, Lange, Schwabe, and Yang, "High-speed high-security signatures."
  // J Crypt Eng 2(2):77--89, Sept. 2012. http://ed25519.cr.yp.to/ed25519-20110926.pdf
  var tmp1 = gx0Den.pow(7);
  var tmp2 = gx0Num * tmp1;
  tmp1 = tmp1 * tmp2 * gx0Den;
  var sqrtCandidate =
      tmp2 * tmp1.pow((EC.q * EC.q - BigInt.from(9)) ~/ BigInt.from(16));
  // check if g(X0(t)) is square and return the sqrt if so
  // print(sqrtCandidate);
  for (var root in rootOfUnity) {
    var y0 = sqrtCandidate * root;
    if (y0.pow(2) * gx0Den == gx0Num) {
      // found sqrt(g(X0(t))). force sign of y to equal sign of t
      if (sgn0(y0) != sgn0(t)) {
        y0 = -y0;
      }
      assert(sgn0(y0) == sgn0(t));
      return JacobianPoint(
          x: x0Num * x0Den,
          y: y0 * x0Den.pow(3),
          z: x0Den,
          infinity: false,
          type: Fq2);
    }
  }
  // if we've gotten here, then g(X0(t)) is not square. convert srqt_candidate to sqrt(g(X1(t)))
  var x1Num = xi2 * t.pow(2) * x0Num;
  var x1Den = x0Den;
  var gx1Num = xi2.pow(3) * t.pow(6) * gx0Num;
  var gx1Den = gx0Den;
  sqrtCandidate *= t.pow(3);
  for (var eta in etas) {
    var y1 = eta * sqrtCandidate;
    if (y1.pow(2) * gx1Den == gx1Num) {
      // found sqrt(g(X1(t))). force sign of y to equal sign of t
      if (sgn0(y1) != sgn0(t)) {
        y1 = -y1;
      }
      assert(sgn0(y1) == sgn0(t));
      return JacobianPoint(
          x: x1Num * x1Den,
          y: y1 * x1Den.pow(3),
          z: x1Den,
          infinity: false,
          type: Fq2);
    }
  }
  // if we got here, something is wrong
  throw Exception('Error, osswu2_help failed for unknown reasons');
}

JacobianPoint iso3(JacobianPoint point) {
  Iterable<Iterable<Fq2>> mapCoeffs = [xnum, xden, ynum, yden];
  return evalIso(point, mapCoeffs);
}

BigInt sgn0(Fq2 x) {
  // https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-07#section-4.
  var sign0 = x.fqs.elementAt(0).value % BigInt.two;
  // ignore: unrelated_type_equality_checks
  var zero0 = x.fqs.elementAt(0) == 0;
  var sign1 = x.fqs.elementAt(1).value % BigInt.two;
  if (zero0 && sign0 != BigInt.zero) {
    return sign0;
  } else if (zero0 && sign0 == BigInt.zero) {
    return sign1;
  } else {
    return sign0;
  }
}
