use anyhow::Result;
use clap::{Arg, Command};

pub mod app;
pub mod cli;
pub mod config;
pub mod kcl;
pub mod taskfile;
pub mod tui;

use app::App;

#[tokio::main]
async fn main() -> Result<()> {
    let matches = Command::new("task-manager")
        .about("A TUI application for managing go-task Taskfiles with KCL validation")
        .version("0.1.0")
        .arg(
            Arg::new("file")
                .short('f')
                .long("file")
                .value_name("FILE")
                .help("Taskfile to open")
                .default_value("Taskfile.yml"),
        )
        .arg(
            Arg::new("config")
                .short('c')
                .long("config")
                .value_name("CONFIG")
                .help("Configuration file"),
        )
        .get_matches();

    let taskfile_path = matches.get_one::<String>("file").unwrap();
    let config_path = matches.get_one::<String>("config");

    let mut app = App::new(taskfile_path, config_path).await?;
    let mut terminal = tui::init()?;
    
    let result = app.run(&mut terminal).await;
    
    tui::restore()?;
    
    result
}
