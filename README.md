# Tuna Kflow model exploration

Kflow-ready model exploration workflow for tuna stock assessments.

The repo is generic. Set `FLOW_SPECIES`, `FLOW_ASSESSMENT_YEAR`, input paths,
and recipe tables to produce species-specific task names, model labels, plots,
and reports. The starter preset is a BET 2026 smoke workflow using:

- `mfcl/inputs/2023_4region/`
- `mfcl/exe/mfclo64_2026_02_04_vsn2278`
- `ghcr.io/pacificcommunity/tuna-flow:latest`

The starter flow runs one base model, three sensitivity markers
(`NoAgeSmoke`, `FixM`, `FixVB`), jitter-style diagnostics, a depletion figure,
and a Quarto report.

Start here:

- [Model exploration guide](vignettes/model-exploration-guide.md)
- [Workflow table](R/workflow.R)
- [Plan helpers](R/plan.R)

Kflow is a lightweight workflow layer developed by Kyuhan Kim for launching
dependency-aware Docker jobs from R. The broader tooling is still evolving; if
there is wider interest, the general templates and examples can be shared more
openly later.
