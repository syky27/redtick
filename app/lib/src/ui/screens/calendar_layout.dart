/// Like [packOverlapColumns], but intervals shorter than [minDuration] do **not**
/// participate in column allocation: they're laid out at full width (col 0 of 1)
/// and ignored when packing the rest. This stops a stray few-second blip from
/// squeezing a real, long entry into a narrow column — only meaningfully-long
/// entries split into side-by-side columns when they genuinely overlap.
///
/// Returns lanes aligned to the input order.
List<({int col, int columns})> packOverlapColumnsIgnoringShort(
    List<({DateTime start, DateTime end})> intervals, Duration minDuration) {
  final result =
      List<({int col, int columns})>.filled(intervals.length, (col: 0, columns: 1));
  final packableIdx = <int>[];
  final packable = <({DateTime start, DateTime end})>[];
  for (var i = 0; i < intervals.length; i++) {
    if (intervals[i].end.difference(intervals[i].start) >= minDuration) {
      packableIdx.add(i);
      packable.add(intervals[i]);
    }
  }
  final packed = packOverlapColumns(packable);
  for (var k = 0; k < packableIdx.length; k++) {
    result[packableIdx[k]] = packed[k];
  }
  return result;
}

/// Pure interval column-packing for the day calendar — no Flutter imports so it
/// stays unit-testable.
///
/// Given time [intervals] in arbitrary order, returns a list **aligned to the
/// input** where each element is `(col, columns)`:
///  - `col`     — the 0-based column the interval should occupy.
///  - `columns` — the number of side-by-side columns in that interval's overlap
///    cluster, so its width is `1 / columns`. `columns == 1` ⇒ no overlap ⇒
///    full width.
///
/// Intervals that merely touch (`a.end == b.start`) are treated as
/// non-overlapping and may share a column.
List<({int col, int columns})> packOverlapColumns(
    List<({DateTime start, DateTime end})> intervals) {
  final n = intervals.length;
  final result =
      List<({int col, int columns})>.filled(n, (col: 0, columns: 1));
  if (n == 0) return result;

  // Sort indices by start, then end — keep the original index to scatter back.
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final c = intervals[a].start.compareTo(intervals[b].start);
      return c != 0 ? c : intervals[a].end.compareTo(intervals[b].end);
    });

  // Indices of the current overlap cluster, and the cluster's max end-time.
  var cluster = <int>[];
  DateTime? clusterEnd;

  void flush() {
    if (cluster.isEmpty) return;
    final colEnds = <DateTime>[]; // last end-time placed in each column
    final colOf = <int, int>{}; // original index -> assigned column
    for (final i in cluster) {
      final iv = intervals[i];
      var placed = -1;
      for (var c = 0; c < colEnds.length; c++) {
        if (!iv.start.isBefore(colEnds[c])) {
          // start >= colEnds[c] -> this column is free to reuse.
          colEnds[c] = iv.end;
          placed = c;
          break;
        }
      }
      if (placed == -1) {
        colEnds.add(iv.end);
        placed = colEnds.length - 1;
      }
      colOf[i] = placed;
    }
    final columns = colEnds.length;
    for (final i in cluster) {
      result[i] = (col: colOf[i]!, columns: columns);
    }
    cluster = [];
    clusterEnd = null;
  }

  for (final i in order) {
    final iv = intervals[i];
    if (clusterEnd != null && !iv.start.isBefore(clusterEnd!)) {
      // start >= clusterEnd -> no overlap with anything in the cluster.
      flush();
    }
    cluster.add(i);
    clusterEnd = clusterEnd == null
        ? iv.end
        : (iv.end.isAfter(clusterEnd!) ? iv.end : clusterEnd!);
  }
  flush();

  return result;
}
