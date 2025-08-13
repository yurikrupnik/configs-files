use cluster_cli::{Cli, Commands, handle_cluster_command, handle_script_command, handle_monitor_command, handle_cost_command};
use clap::Parser;
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Cluster { action } => handle_cluster_command(action).await,
        Commands::Script { action } => handle_script_command(action).await,
        Commands::Monitor { environment, watch } => handle_monitor_command(environment, watch).await,
        Commands::Cost { action } => handle_cost_command(action).await,
    }
}
