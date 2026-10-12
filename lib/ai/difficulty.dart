/// How hard the computer plays. Each level changes the decision strategy,
/// not just a delay:
///
///  * Easy   - no lookahead. Picks a scoring move at random, weighted
///             towards bigger words, so it is legal but beatable.
///  * Medium - 2-ply search: its move minus the opponent's best reply.
///  * Hard   - 3-ply search (adds its own follow-up) with alpha-beta.
///  * Expert - up to 5-ply iterative-deepening alpha-beta search.
///
/// Deeper levels search a "beam" of the best-scoring candidates at each
/// ply (plus a few zero-point moves) so the cost stays bounded, and are
/// also capped by a wall-clock [timeBudget]: iterative deepening keeps the
/// result of the last fully searched depth.
enum AiDifficulty {
  easy('Easy', 0, <int>[], 0),
  medium('Medium', 2, <int>[10, 6], 2),
  hard('Hard', 3, <int>[14, 8, 6], 3),
  expert('Expert', 5, <int>[14, 8, 6, 5, 4], 6);

  final String label;

  /// Search depth in plies (half-moves). 0 means "no search".
  final int plies;

  /// Max candidates examined at each ply (index 0 = the computer's move).
  final List<int> beams;

  /// Wall-clock cap in seconds for the deepening search.
  final int timeBudgetSeconds;

  const AiDifficulty(this.label, this.plies, this.beams, this.timeBudgetSeconds);

  Duration get timeBudget => Duration(seconds: timeBudgetSeconds);

  int beamAt(int ply) => beams[ply < beams.length ? ply : beams.length - 1];

  static AiDifficulty fromName(String? name) {
    for (final d in AiDifficulty.values) {
      if (d.name == name) return d;
    }
    return AiDifficulty.medium;
  }
}
