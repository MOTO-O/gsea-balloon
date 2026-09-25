# GSEA Balloon Plot

A Shiny / Shinylive tool for plotting GSEA comparisons. Colour = signed NES; circle size = −log10(padj). Only genesets present in all included input files are eligible.

The editable source is **app/**. Root-level **app.json**, **index.html**, **shinylive/** and **edit/** are generated deployment files. Do not hand-edit app.json. The current layout preserves GitHub Pages' `main / (root)` setting.

- [Release notes](CHANGELOG.md)
- [GitHub Pages site](https://moto-o.github.io/gsea-balloon/)

## Run locally

Open `app/install_packages.R` in RStudio and click Source once if dependencies are missing, then Source `app/run_app.R`. Uploaded GSEA results require `pathway`, `NES`, `padj` columns by default. Bundled examples are synthetic.

## Geneset selection and outlines

Leave selection fields blank to retain all common genesets. The minimum-padj cutoff uses **min(raw padj) across included comparisons**; at least one comparison must pass. It does not mean all comparisons pass. Missing padj values are ignored; when selection is enabled, all-missing genesets are excluded. A low minimum padj reflects statistical significance, not necessarily a large absolute NES.

Top N is applied after the cutoff and selects the N smallest minima. Equal minima are resolved by geneset name in radix order, so at most N genesets are shown. Display order follows the original ordering option or hierarchical clustering, rather than necessarily rank order. Clustering uses the retained genesets; changing the filter can change the sample clustering. Automatic colour/size limits use the displayed plottable cells; fix ranges for cross-plot comparison.

The separate outline option uses **each individual circle's raw padj**. Values at or below the outline cutoff receive a black 0.5-pt border. It does not outline every circle in a retained geneset. Other circles retain their normal outline. Settings JSON records the options and all candidate genesets' minima, ranks and selection flags. Plot data contains the displayed genesets and, when enabled, per-cell highlight flags.

In Shinylive, click **PDF** and then **Save …pdf**. Other formats use the same two-step process. Local R uses standard Shiny downloads.

## Test and rebuild

From the repository root in RStudio's Terminal:

```sh
Rscript tests/test_features.R
Rscript tools/build_site.R
```

Install `shinylive` on the developer PC before rebuilding. Both helper files under tools/ can also be opened and sourced in RStudio. `tools/preview_site.R` serves the generated site locally. Only `app.R`, `R/`, `www/` and synthetic `examples/` are included in the exported application.

Version 1.2.0 was checked with native R 4.4.0 / ggplot2 4.0.2, shinylive exporter 0.5.0 and Shinylive assets 0.10.12. The compiled assets and resolved package versions are part of the site snapshot. Rebuilding later may resolve different package versions; inspect diffs and re-test. Do not claim that a tag alone pins every dependency.

Place private analysis files outside this repository. `local-data/` and `local-output/` are ignored as an additional convenience, not as access control; already-tracked files are not protected by .gitignore.
