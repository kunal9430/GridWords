import 'package:flutter_test/flutter_test.dart';
import 'package:grid_word_game/services/scoreboard_name_resolver.dart';

void main() {
  group('Text classification', () {
    test('emoji-and-letters mix ignores emoji for the monogram', () {
      final r = ScoreboardNameResolver.resolve(player1: '😎 Kunal 🚀', player2: 'Zed');
      expect(r.player1Label, 'KU'); // "Kunal" is a single word -> first two letters
    });

    test('alphanumeric with trailing emoji ignores the emoji', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Alex99 🎉', player2: 'Zed');
      expect(r.player1Label, 'AL');
    });

    test('pure emoji name keeps up to two grapheme clusters as-is', () {
      final r = ScoreboardNameResolver.resolve(player1: '😎🚀🔥', player2: 'Zed');
      expect(r.player1Label, '😎🚀');
    });

    test('single emoji name stays a single cluster', () {
      final r = ScoreboardNameResolver.resolve(player1: '💲', player2: 'Zed');
      expect(r.player1Label, '💲');
    });
  });

  group('Standard monogram derivation', () {
    test('two words -> first letter of each, uppercased', () {
      final r = ScoreboardNameResolver.resolve(player1: 'kunal kumar', player2: 'Zed');
      expect(r.player1Label, 'KK');
    });

    test('three+ words -> first letter of first two words only', () {
      final r = ScoreboardNameResolver.resolve(player1: 'john doe smith', player2: 'Zed');
      expect(r.player1Label, 'JD');
    });

    test('single word length >= 2 -> first two letters', () {
      final r = ScoreboardNameResolver.resolve(player1: 'kunal', player2: 'Zed');
      expect(r.player1Label, 'KU');
    });

    test('single-letter word -> that one letter', () {
      final r = ScoreboardNameResolver.resolve(player1: 'k', player2: 'Zed');
      expect(r.player1Label, 'K');
    });
  });

  group('Collision resolution - text vs text', () {
    test('multi-word collision differentiated by first word', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Kunal Kumar', player2: 'Kevin Klein');
      expect(r.player1Label, isNot(equals(r.player2Label)));
      expect(r.player1Label, 'KU');
      expect(r.player2Label, 'KE');
    });

    test('multi-word collision with identical first words falls back to second word', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Kunal Kumar', player2: 'Kunal Kapoor');
      expect(r.player1Label, isNot(equals(r.player2Label)));
    });

    test('fully identical multi-word names get numeric suffixes', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Kunal Kumar', player2: 'Kunal Kumar');
      expect(r.player1Label, isNot(equals(r.player2Label)));
      expect(r.player1Label, endsWith('1'));
      expect(r.player2Label, endsWith('2'));
    });

    test('single-word collision expands using first+last letter', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Alex', player2: 'Alan');
      expect(r.player1Label, 'AX');
      expect(r.player2Label, 'AN');
    });

    test('identical single-word names get numeric suffixes', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Kunal', player2: 'Kunal');
      expect(r.player1Label, 'K1');
      expect(r.player2Label, 'K2');
    });
  });

  group('Collision resolution - emoji vs emoji', () {
    test('identical single emoji gets a numeric suffix', () {
      final r = ScoreboardNameResolver.resolve(player1: '😎', player2: '😎');
      expect(r.player1Label, '😎1');
      expect(r.player2Label, '😎2');
    });
  });

  group('No collision - labels pass through untouched', () {
    test('clearly different names are left alone', () {
      final r = ScoreboardNameResolver.resolve(player1: 'Rajat Rai', player2: 'Karan Kumar');
      expect(r.player1Label, 'RR');
      expect(r.player2Label, 'KK');
    });
  });
}
