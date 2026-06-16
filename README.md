# BET 2026 Kflow model exploration

Kflow-ready model exploration workflow for the 2026 Bigeye tuna assessment in
[`PacificCommunity/ofp-sam-2026-BET`](https://github.com/PacificCommunity/ofp-sam-2026-BET).

This repository is intentionally thin but runnable. It includes the current
starter MFCL input set from the assessment repository and the MFCL executable
needed for a fast smoke run:

- `mfcl/inputs/2023_4region/`
- `mfcl/exe/mfclo64_2026_02_04_vsn2278`

The first end-to-end flow is deliberately small:

1. `bet2026-base`: run the included 4-region input through `mfcl -makepar`.
2. `bet2026-sensitivity`: create a `NoAgeSmoke` sensitivity recipe and run the
   same fast MFCL smoke check.
3. `bet2026-diagnostics`: create a short jitter-style diagnostics summary.
4. `bet2026-plot`: create a simple depletion plot package.
5. `bet2026-report`: render a Quarto HTML report that includes the plot.

The workflow folders here are the readable launch layer:

- `base/`: run one base MFCL model.
- `sensitivity/`: run one sensitivity model from a selected base job.
- `diagnostics/`: run diagnostics from either a base job or a sensitivity job.
- `plot/`: create plot outputs from selected diagnostics or model outputs.
- `report/`: render a Quarto report from selected plot outputs.

The design is meant for large model exploration: hundreds or thousands of base
models, sensitivity runs, diagnostics, plots, and reports. Kflow handles the job
dependencies; the R tables in this repo keep model names, change tokens, input
variants, and parent-child links easy to inspect.

## What is Kflow?

Kflow is a lightweight workflow layer developed by Kyuhan Kim for launching
dependency-aware analysis jobs from R. It is designed for work where many
Docker-based jobs need to run on remote compute, pass outputs to downstream
jobs, and remain easy to audit later.

This repository uses Kflow for a concrete BET assessment workflow. The broader
Kflow tooling is still evolving. If there is wider interest, the general Kflow
templates, documentation, and examples can be shared more openly later.

The default backend is the MFCL executable included in this repository:
`mfcl/exe/mfclo64_2026_02_04_vsn2278`. The repo is structured so
`MFCL_BACKEND=mfclrtmb` can be added later through a backend script without
changing the Kflow dependency layout.

## One-time setup

Local R is only used to register tasks and launch jobs. The model runs happen
inside the Kflow Docker runtime.

Default runtime image:

```text
ghcr.io/pacificcommunity/bet2026-flow:latest
```

```r
install.packages("remotes")
remotes::install_github("kyuhank/KflowKit", auth_token = Sys.getenv("GITHUB_PAT"))
```

Private helper packages such as `mfclkit`, `mfclshiny`, `mfclrtmb`, and
`KflowKit` are updated at Docker container startup when `GIT_PAT` or
`GITHUB_PAT` is available. The smoke path has fallbacks so the public image can
still run the included example without exposing private package code.

Kflow needs API access:

```r
Sys.setenv(KFLOW_URL = "http://127.0.0.1:8089")
Sys.setenv(KFLOW_API_TOKEN = "paste-token-from-kflow")
```

If Kflow needs a GitHub token to read private helper repositories later, set:

```r
Sys.setenv(GITHUB_PAT = "ghp_...")
```

## Register tasks

Run once after pushing or changing this repository:

```r
source("R/workflow.R")
register_tasks()
```

or:

```bash
Rscript scripts/register-kflow-tasks.R
```

## Edit and launch from R

Open `R/workflow.R`. The top section is the part you normally edit for small
manual runs:

```r
base_models
sensitivity_models
diagnostics_runs
plot_runs
report_runs
```

Add a row to add a model. Delete a row to skip it. Change columns such as
`MAKE_TARGETS`, `BASE_DIR`, `MODEL_DIR`, `SOURCE_REF`, or `JOB_DESCRIPTION` to
change the job environment.

For larger exploration plans, use `R/plan.R`:

```r
source("R/workflow.R")
source("R/plan.R")

plan <- build_exploration_plan(
  bases = base_models,
  sensitivities = sensitivity_models,
  diagnostics = diagnostic_recipes(),
  plots = plot_recipes(),
  reports = report_recipes()
)

preview_plan(plan)

# Launch only a few jobs while testing.
launch_plan(plan, stages = "base", limit = 3)

# Later, launch wider batches.
launch_plan(plan, stages = c("sensitivity", "diagnostics"), batch_size = 50)
```

Example:

```r
source("R/workflow.R")

base_jobs <- launch_base()
sensitivity_jobs <- launch_sensitivity()
diagnostic_jobs <- launch_diagnostics()
plot_jobs <- launch_plot()
report_jobs <- launch_report()
```

To run the included starter flow:

```r
source("R/workflow.R")
launch_example_flow()
```

## Flexible links

Links are controlled by two columns in the R tables:

- `INPUT_TASK`: the upstream Kflow task, for example `bet2026-base` or
  `bet2026-sensitivity`.
- `INPUT_KEY`: the upstream job key, for example `base-4r-smoke` or
  `sens-noAgeSmoke`.

That means these are all valid:

- base -> diagnostics
- base -> sensitivity -> diagnostics
- diagnostics -> plot -> report
- several sensitivities -> one plot
- several plots -> one report

For large plans, the same link information lives in a plan table:

```r
plan$diagnostics[, c("JOB_KEY", "INPUT_TASK", "INPUT_KEY", "MODEL_TOKEN", "CHANGE_SUMMARY")]
```

For example, to diagnose the base model directly after adding a base-diagnostics
row:

```r
row <- diagnostics_from(
  input_task = "bet2026-base",
  input_key = "base-4r-smoke",
  job_key = "diag-base4r-jitter",
  token = "Base4R_Jitter",
  base_dir = "mfcl/inputs/2023_4region",
  model_dir = "model/diag-base4r-jitter"
)
row$MFCL_BACKEND <- "diagnostics_smoke"
launch_diagnostics(row)
```

To diagnose a sensitivity:

```r
diagnostics_runs$INPUT_TASK[diagnostics_runs$JOB_KEY == "diag-noAgeSmoke-jitter"] <- "bet2026-sensitivity"
diagnostics_runs$INPUT_KEY[diagnostics_runs$JOB_KEY == "diag-noAgeSmoke-jitter"] <- "sens-noAgeSmoke"
launch_diagnostics(diagnostics_runs[diagnostics_runs$JOB_KEY == "diag-noAgeSmoke-jitter", ])
```

## Naming and model metadata

Every job writes the same metadata files:

- `model-registry.csv`
- `model-registry.json`
- `kflow-job-summary.csv`
- `input-manifest.csv`
- `source-artifacts-manifest.csv`

The important columns are:

- `MODEL_TOKEN`: short readable model token, for example `Base4R`, `NoAgeSmoke`, `NoAgeSmoke_Jitter`.
- `MODEL_KEY`: stable Kflow key, usually the same as `JOB_KEY`.
- `BASE_MODEL_KEY`: the base model this run came from.
- `CHANGE_TOKEN`: compact token for what changed, for example `NoAgeSmoke`.
- `CHANGE_GROUP`: broad grouping such as `age-data`, `tagging`, `growth`, `diagnostics`.
- `CHANGE_SUMMARY`: one-sentence human explanation.
- `INPUT_VARIANT`: input folder or input recipe name.
- `PATCH_SCRIPT`: optional R script used to edit `.ini`, `.frq`, `.tag`, `.par`, or other inputs.

These metadata files are designed so model results can later be collected into
one table for regression trees, decision trees, screening plots, or audit
reports.

The plot stage writes joined registry/summary tables from its inputs. That is
the clean insertion point for later regression-tree or decision-tree code: read
the input `model-registry.csv` and model result summaries, fit the tree, save
the tree plot, and the report stage will automatically include generated plots.

## Input patch scripts

Each model stage can run an optional patch script before the `make` target. This
is the easiest way to add a new base model or sensitivity without hiding the
change in a long command.

Typical workflow:

1. Copy one of the examples in `base/patches/` or `sensitivity/patches/`.
2. Edit the script so it modifies the relevant `.ini`, `.frq`, `.tag`, `.par`,
   or other input files.
3. Add one row in `R/workflow.R` with `PATCH_SCRIPT`, `PATCH_INPUT_DIR`,
   `PATCH_OUTPUT_DIR`, `MODEL_TOKEN`, and `CHANGE_SUMMARY`.
4. Launch from R.

Patch scripts receive these environment variables:

- `KFLOW_PATCH_SOURCE_DIR`: source checkout used by the job.
- `KFLOW_PATCH_INPUT_DIR`: input directory to read.
- `KFLOW_PATCH_OUTPUT_DIR`: output directory to write.
- `KFLOW_PATCH_STAGE`: `base`, `sensitivity`, or `diagnostics`.
- `PATCH_ARGS`: optional free text for your script to parse.

The script should write modified inputs to `KFLOW_PATCH_OUTPUT_DIR`. The job
then runs `MAKE_TARGETS` with the env values from the R table.

## Packages and helper repos

The active job path uses:

- `KflowKit`: register and launch Kflow jobs from R.
- `mfcl/exe/mfclo64_2026_02_04_vsn2278`: the current MFCL executable backend.
- `mfclkit`: optional helper layer when installed in the Docker runtime.
- `mfclshiny`: optional plot/payload backend when installed in the Docker runtime.
- `mfclrtmb`: optional future backend when installed in the Docker runtime.

The starter rows use `MFCL_BACKEND=mfcl_smoke` for a fast executable check. For
full make-target runs, use `MFCL_BACKEND=mfcl_exe`. To experiment later with the
RTMB backend, set `MFCL_BACKEND=mfclrtmb` and provide `BACKEND_SCRIPT` or
`BACKEND_COMMAND` in the R table row.
