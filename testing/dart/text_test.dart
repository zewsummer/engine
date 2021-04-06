// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.6
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:test/test.dart';

void main() {
  group('FontWeight.lerp', () {
    test('works with non-null values', () {
      expect(FontWeight.lerp(FontWeight.w400, FontWeight.w600, .5), equals(FontWeight.w500));
    });

    test('returns null if a and b are null', () {
      expect(FontWeight.lerp(null, null, 0), isNull);
    });

    test('returns FontWeight.w400 if a is null', () {
      expect(FontWeight.lerp(null, FontWeight.w400, 0), equals(FontWeight.w400));
    });

    test('returns FontWeight.w400 if b is null', () {
      expect(FontWeight.lerp(FontWeight.w400, null, 1), equals(FontWeight.w400));
    });
  });

  group('ParagraphStyle', () {
    final ParagraphStyle ps0 = ParagraphStyle(textDirection: TextDirection.ltr, fontSize: 14.0);
    final ParagraphStyle ps1 = ParagraphStyle(textDirection: TextDirection.rtl, fontSize: 14.0);
    final ParagraphStyle ps2 = ParagraphStyle(textAlign: TextAlign.center, fontWeight: FontWeight.w800, fontSize: 10.0, height: 100.0);
    final ParagraphStyle ps3 = ParagraphStyle(fontWeight: FontWeight.w700, fontSize: 12.0, height: 123.0);

    test('toString works', () {
      expect(ps0.toString(), equals('ParagraphStyle(textAlign: unspecified, textDirection: TextDirection.ltr, fontWeight: unspecified, fontStyle: unspecified, maxLines: unspecified, textHeightBehavior: unspecified, fontFamily: unspecified, fontSize: 14.0, height: unspecified, ellipsis: unspecified, locale: unspecified)'));
      expect(ps1.toString(), equals('ParagraphStyle(textAlign: unspecified, textDirection: TextDirection.rtl, fontWeight: unspecified, fontStyle: unspecified, maxLines: unspecified, textHeightBehavior: unspecified, fontFamily: unspecified, fontSize: 14.0, height: unspecified, ellipsis: unspecified, locale: unspecified)'));
      expect(ps2.toString(), equals('ParagraphStyle(textAlign: TextAlign.center, textDirection: unspecified, fontWeight: FontWeight.w800, fontStyle: unspecified, maxLines: unspecified, textHeightBehavior: unspecified, fontFamily: unspecified, fontSize: 10.0, height: 100.0x, ellipsis: unspecified, locale: unspecified)'));
      expect(ps3.toString(), equals('ParagraphStyle(textAlign: unspecified, textDirection: unspecified, fontWeight: FontWeight.w700, fontStyle: unspecified, maxLines: unspecified, textHeightBehavior: unspecified, fontFamily: unspecified, fontSize: 12.0, height: 123.0x, ellipsis: unspecified, locale: unspecified)'));
    });
  });

  group('TextStyle', () {
    final TextStyle ts0 = TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0, height: 123.0);
    final TextStyle ts1 = TextStyle(color: const Color(0xFF00FF00), fontWeight: FontWeight.w800, fontSize: 10.0, height: 100.0);
    final TextStyle ts2 = TextStyle(fontFamily: 'test');
    final TextStyle ts3 = TextStyle(fontFamily: 'foo', fontFamilyFallback: <String>['Roboto', 'test']);
    final TextStyle ts4 = TextStyle(leadingDistribution: TextLeadingDistribution.even);

    test('toString works', () {
      expect(
        ts0.toString(),
        equals('TextStyle(color: unspecified, decoration: unspecified, decorationColor: unspecified, decorationStyle: unspecified, decorationThickness: unspecified, fontWeight: FontWeight.w700, fontStyle: unspecified, textBaseline: unspecified, fontFamily: unspecified, fontFamilyFallback: unspecified, fontSize: 12.0, letterSpacing: unspecified, wordSpacing: unspecified, height: 123.0x, leadingDistribution: unspecified, locale: unspecified, background: unspecified, foreground: unspecified, shadows: unspecified, fontFeatures: unspecified)'),
      );
      expect(
        ts1.toString(),
        equals('TextStyle(color: Color(0xff00ff00), decoration: unspecified, decorationColor: unspecified, decorationStyle: unspecified, decorationThickness: unspecified, fontWeight: FontWeight.w800, fontStyle: unspecified, textBaseline: unspecified, fontFamily: unspecified, fontFamilyFallback: unspecified, fontSize: 10.0, letterSpacing: unspecified, wordSpacing: unspecified, height: 100.0x, leadingDistribution: unspecified, locale: unspecified, background: unspecified, foreground: unspecified, shadows: unspecified, fontFeatures: unspecified)'),
      );
      expect(
        ts2.toString(),
        equals('TextStyle(color: unspecified, decoration: unspecified, decorationColor: unspecified, decorationStyle: unspecified, decorationThickness: unspecified, fontWeight: unspecified, fontStyle: unspecified, textBaseline: unspecified, fontFamily: test, fontFamilyFallback: unspecified, fontSize: unspecified, letterSpacing: unspecified, wordSpacing: unspecified, height: unspecified, leadingDistribution: unspecified, locale: unspecified, background: unspecified, foreground: unspecified, shadows: unspecified, fontFeatures: unspecified)'),
      );
      expect(
        ts3.toString(),
        equals('TextStyle(color: unspecified, decoration: unspecified, decorationColor: unspecified, decorationStyle: unspecified, decorationThickness: unspecified, fontWeight: unspecified, fontStyle: unspecified, textBaseline: unspecified, fontFamily: foo, fontFamilyFallback: [Roboto, test], fontSize: unspecified, letterSpacing: unspecified, wordSpacing: unspecified, height: unspecified, leadingDistribution: unspecified, locale: unspecified, background: unspecified, foreground: unspecified, shadows: unspecified, fontFeatures: unspecified)'),
      );
      expect(
        ts4.toString(),
        equals('TextStyle(color: unspecified, decoration: unspecified, decorationColor: unspecified, decorationStyle: unspecified, decorationThickness: unspecified, fontWeight: unspecified, fontStyle: unspecified, textBaseline: unspecified, fontFamily: unspecified, fontFamilyFallback: unspecified, fontSize: unspecified, letterSpacing: unspecified, wordSpacing: unspecified, height: unspecified, leadingDistribution: TextLeadingDistribution.even, locale: unspecified, background: unspecified, foreground: unspecified, shadows: unspecified, fontFeatures: unspecified)'),
      );
    });
  });

  group('TextHeightBehavior', () {
    const TextHeightBehavior behavior0 = TextHeightBehavior();
    const TextHeightBehavior behavior1 = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false
    );
    const TextHeightBehavior behavior2 = TextHeightBehavior(
      applyHeightToFirstAscent: false,
    );
    const TextHeightBehavior behavior3 = TextHeightBehavior(
      applyHeightToLastDescent: false
    );
    const TextHeightBehavior behavior4 = TextHeightBehavior(
      applyHeightToLastDescent: false,
      leadingDistribution: TextLeadingDistribution.even,
    );

    test('default constructor works', () {
      expect(behavior0.applyHeightToFirstAscent, equals(true));
      expect(behavior0.applyHeightToLastDescent, equals(true));

      expect(behavior1.applyHeightToFirstAscent, equals(false));
      expect(behavior1.applyHeightToLastDescent, equals(false));

      expect(behavior2.applyHeightToFirstAscent, equals(false));
      expect(behavior2.applyHeightToLastDescent, equals(true));

      expect(behavior3.applyHeightToFirstAscent, equals(true));
      expect(behavior3.applyHeightToLastDescent, equals(false));

      expect(behavior4.applyHeightToLastDescent, equals(false));
      expect(behavior4.leadingDistribution, equals(TextLeadingDistribution.even));
    });

    test('encode works', () {
      expect(behavior0.encode(), equals(0));
      expect(behavior1.encode(), equals(3));
      expect(behavior2.encode(), equals(1));
      expect(behavior3.encode(), equals(2));
      expect(behavior4.encode(), equals(6));
    });

    test('decode works', () {
      expect(TextHeightBehavior.fromEncoded(0), equals(behavior0));
      expect(TextHeightBehavior.fromEncoded(3), equals(behavior1));
      expect(TextHeightBehavior.fromEncoded(1), equals(behavior2));
      expect(TextHeightBehavior.fromEncoded(2), equals(behavior3));
      expect(TextHeightBehavior.fromEncoded(6), equals(behavior4));
    });

    test('toString works', () {
      expect(behavior0.toString(), equals('TextHeightBehavior(applyHeightToFirstAscent: true, applyHeightToLastDescent: true, leadingDistribution: TextLeadingDistribution.proportional)'));
      expect(behavior1.toString(), equals('TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false, leadingDistribution: TextLeadingDistribution.proportional)'));
      expect(behavior2.toString(), equals('TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: true, leadingDistribution: TextLeadingDistribution.proportional)'));
      expect(behavior3.toString(), equals('TextHeightBehavior(applyHeightToFirstAscent: true, applyHeightToLastDescent: false, leadingDistribution: TextLeadingDistribution.proportional)'));
      expect(behavior4.toString(), equals('TextHeightBehavior(applyHeightToFirstAscent: true, applyHeightToLastDescent: false, leadingDistribution: TextLeadingDistribution.even)'));
    });
  });

  group('TextRange', () {
    test('empty ranges are correct', () {
      const TextRange range = TextRange(start: -1, end: -1);
      expect(range, equals(const TextRange.collapsed(-1)));
      expect(range, equals(TextRange.empty));
    });
    test('isValid works', () {
      expect(TextRange.empty.isValid, isFalse);
      expect(const TextRange(start: 0, end: 0).isValid, isTrue);
      expect(const TextRange(start: 0, end: 10).isValid, isTrue);
      expect(const TextRange(start: 10, end: 10).isValid, isTrue);
      expect(const TextRange(start: -1, end: 10).isValid, isFalse);
      expect(const TextRange(start: 10, end: 0).isValid, isTrue);
      expect(const TextRange(start: 10, end: -1).isValid, isFalse);
    });
    test('isCollapsed works', () {
      expect(TextRange.empty.isCollapsed, isTrue);
      expect(const TextRange(start: 0, end: 0).isCollapsed, isTrue);
      expect(const TextRange(start: 0, end: 10).isCollapsed, isFalse);
      expect(const TextRange(start: 10, end: 10).isCollapsed, isTrue);
      expect(const TextRange(start: -1, end: 10).isCollapsed, isFalse);
      expect(const TextRange(start: 10, end: 0).isCollapsed, isFalse);
      expect(const TextRange(start: 10, end: -1).isCollapsed, isFalse);
    });
    test('isNormalized works', () {
      expect(TextRange.empty.isNormalized, isTrue);
      expect(const TextRange(start: 0, end: 0).isNormalized, isTrue);
      expect(const TextRange(start: 0, end: 10).isNormalized, isTrue);
      expect(const TextRange(start: 10, end: 10).isNormalized, isTrue);
      expect(const TextRange(start: -1, end: 10).isNormalized, isTrue);
      expect(const TextRange(start: 10, end: 0).isNormalized, isFalse);
      expect(const TextRange(start: 10, end: -1).isNormalized, isFalse);
    });
    test('textBefore works', () {
      expect(const TextRange(start: 0, end: 0).textBefore('hello'), isEmpty);
      expect(const TextRange(start: 1, end: 1).textBefore('hello'), equals('h'));
      expect(const TextRange(start: 1, end: 2).textBefore('hello'), equals('h'));
      expect(const TextRange(start: 5, end: 5).textBefore('hello'), equals('hello'));
      expect(const TextRange(start: 0, end: 5).textBefore('hello'), isEmpty);
    });
    test('textAfter works', () {
      expect(const TextRange(start: 0, end: 0).textAfter('hello'), equals('hello'));
      expect(const TextRange(start: 1, end: 1).textAfter('hello'), equals('ello'));
      expect(const TextRange(start: 1, end: 2).textAfter('hello'), equals('llo'));
      expect(const TextRange(start: 5, end: 5).textAfter('hello'), isEmpty);
      expect(const TextRange(start: 0, end: 5).textAfter('hello'), isEmpty);
    });
    test('textInside works', () {
      expect(const TextRange(start: 0, end: 0).textInside('hello'), isEmpty);
      expect(const TextRange(start: 1, end: 1).textInside('hello'), isEmpty);
      expect(const TextRange(start: 1, end: 2).textInside('hello'), equals('e'));
      expect(const TextRange(start: 5, end: 5).textInside('hello'), isEmpty);
      expect(const TextRange(start: 0, end: 5).textInside('hello'), equals('hello'));
    });
  });

  group('loadFontFromList', () {
    test('will send platform message after font is loaded', () async {
      final PlatformMessageCallback oldHandler = window.onPlatformMessage;
      String actualName;
      String message;
      window.onPlatformMessage = (String name, ByteData data, PlatformMessageResponseCallback callback) {
        actualName = name;
        final Uint8List list = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        message = utf8.decode(list);
      };
      final Uint8List fontData = Uint8List(0);
      await loadFontFromList(fontData, fontFamily: 'fake');
      window.onPlatformMessage = oldHandler;
      expect(actualName, 'flutter/system');
      expect(message, '{"type":"fontsChange"}');
    });
  });

  test('FontFeature class', () {
    expect(const FontFeature.alternative(1), const FontFeature('aalt', 1));
    expect(const FontFeature.alternative(5), const FontFeature('aalt', 5));
    expect(const FontFeature.alternativeFractions(), const FontFeature('afrc', 1));
    expect(const FontFeature.contextualAlternates(), const FontFeature('calt', 1));
    expect(const FontFeature.caseSensitiveForms(), const FontFeature('case', 1));
    expect(      FontFeature.characterVariant(1), const FontFeature('cv01', 1));
    expect(      FontFeature.characterVariant(18), const FontFeature('cv18', 1));
    expect(const FontFeature.denominator(), const FontFeature('dnom', 1));
    expect(const FontFeature.fractions(), const FontFeature('frac', 1));
    expect(const FontFeature.historicalForms(), const FontFeature('hist', 1));
    expect(const FontFeature.historicalLigatures(), const FontFeature('hlig', 1));
    expect(const FontFeature.liningFigures(), const FontFeature('lnum', 1));
    expect(const FontFeature.localeAware(), const FontFeature('locl', 1));
    expect(const FontFeature.localeAware(enable: true), const FontFeature('locl', 1));
    expect(const FontFeature.localeAware(enable: false), const FontFeature('locl', 0));
    expect(const FontFeature.notationalForms(), const FontFeature('nalt', 1));
    expect(const FontFeature.notationalForms(5), const FontFeature('nalt', 5));
    expect(const FontFeature.numerators(), const FontFeature('numr', 1));
    expect(const FontFeature.oldstyleFigures(), const FontFeature('onum', 1));
    expect(const FontFeature.ordinalForms(), const FontFeature('ordn', 1));
    expect(const FontFeature.proportionalFigures(), const FontFeature('pnum', 1));
    expect(const FontFeature.randomize(), const FontFeature('rand', 1));
    expect(const FontFeature.stylisticAlternates(), const FontFeature('salt', 1));
    expect(const FontFeature.scientificInferiors(), const FontFeature('sinf', 1));
    expect(      FontFeature.stylisticSet(1), const FontFeature('ss01', 1));
    expect(      FontFeature.stylisticSet(18), const FontFeature('ss18', 1));
    expect(const FontFeature.subscripts(), const FontFeature('subs', 1));
    expect(const FontFeature.superscripts(), const FontFeature('sups', 1));
    expect(const FontFeature.swash(), const FontFeature('swsh', 1));
    expect(const FontFeature.swash(0), const FontFeature('swsh', 0));
    expect(const FontFeature.swash(5), const FontFeature('swsh', 5));
    expect(const FontFeature.tabularFigures(), const FontFeature('tnum', 1));
    expect(const FontFeature.slashedZero(), const FontFeature('zero', 1));
    expect(const FontFeature.enable('TEST'), const FontFeature('TEST', 1));
    expect(const FontFeature.disable('TEST'), const FontFeature('TEST', 0));
    expect(const FontFeature('FEAT', 1000).feature, 'FEAT');
    expect(const FontFeature('FEAT', 1000).value, 1000);
    expect(const FontFeature('FEAT', 1000).toString(), "FontFeature('FEAT', 1000)");
  });
}
