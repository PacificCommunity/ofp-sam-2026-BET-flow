flow_config <- Sys.getenv("FLOW_CONFIG", file.path("configs", "bet-2026.env"))
if (nzchar(flow_config) && file.exists(flow_config)) {
  readRenviron(flow_config)
}

source("R/workflow.R")
register_tasks()
