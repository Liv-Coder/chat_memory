enum SummarizationMode { oldestFirst, chunked, layered }

class SummarizationConfig {
  final SummarizationMode mode;

  /// Retain this ratio of the most recent messages when summarizing older ones.
  final double recentMessageRetentionRatio;

  /// Chunk size used for `chunked` mode (number of message blocks).
  final int chunkSize;

  const SummarizationConfig({
    this.mode = SummarizationMode.layered,
    this.recentMessageRetentionRatio = 0.7,
    this.chunkSize = 10,
  });
}
