import 'package:flutter_test/flutter_test.dart';
import 'package:grid_word_game/widgets/online_leaderboard.dart';

void main() {
  test('ranking orders by score and ties share a rank', () {
    expect(OnlineLeaderboard.rankedSeats([3, 9, 3]), [1, 0, 2]);
    expect(OnlineLeaderboard.rankOf([3, 9, 3], 1), 1);
    expect(OnlineLeaderboard.rankOf([3, 9, 3], 0), 2);
    expect(OnlineLeaderboard.rankOf([3, 9, 3], 2), 2);
    expect(OnlineLeaderboard.rankOf([0, 0], 1), 1);
  });
}
