# Changelog

## 1.2.0 — prepared 2026-09-24

- Select common genesets using a cutoff on minimum raw padj across included comparisons.
- Optionally keep the top N genesets by that minimum, after applying the cutoff; ties use geneset names.
- Optionally outline each circle with raw padj <= its own cutoff in black at 0.5 PDF points.
- Filter before hierarchical clustering; record selection/ranking in Settings and show displayed/shared counts.
- Retain the pending two-step Blob download fix: PDF (or another export button), then Save.
- Include editable app source, synthetic-data tests, and local build/preview tools in the repository.

Existing public-site commits did not have version tags. This version is a local release candidate until reviewed, committed, pushed and tagged. No historical release tags are implied.
