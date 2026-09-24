# Validation — v1.2.0 candidate (2026-09-24)

- Synthetic tests cover inclusive cutoff boundaries, top N, deterministic tie handling, missing values, invalid inputs, no retained genesets, selected comparison changes, post-filter clustering, per-cell outlines and Settings metadata.
- Native Shiny tests cover reactive updates, stale download protection, all five Blob export payloads, and previous local-folder/upload functionality.
- With features disabled, original data and plot layers still match the standalone English R script.
- Original private data: 9 comparisons / 50 shared genesets. A minimum-padj cutoff of 0.05 and top 20 retained 20 genesets / 180 cells, with 134 outlined cells at per-cell padj <= 0.05. Native and exported webR agree on selection, ranks, clustering leaf orders and statistics. Private input files and private-data tests are not included here.
- The exported WebAssembly runtime produces PDF/PNG/TSV/JSON. PDF content contains 0.50-pt circle outline commands and 0.25-pt panel/grid commands. Rendered small synthetic and real-data plots were inspected.
- Local browser interaction with the exported site verified Version 1.2.0, minimum-padj 0.05 / top 5 controls and outlined circles: 5/12 genesets, 15 cells, 12 highlighted cells.
- The build helper was run twice against the candidate repository. Source, exported app.json and version metadata agree. It preserves root-based Pages publishing and excludes tests/developer tools from the embedded application.

Still requiring confirmation: public-site behavior after deployment and successful file saving in the recipient's browser. Prior download failures led to the retained PDF -> Save Blob method; this record does not claim a completed end-to-end browser save. Windows/Safari/Firefox and very large inputs were not tested.
