pub mod app;
pub mod components;
pub mod events;
pub mod ui;

pub use app::App;
pub use events::{Event, EventHandler};

use crate::{AppState, Result};
use crossterm::{
    event::{self, Event as CrosstermEvent, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    Terminal,
};
use std::{io, time::Duration};
use tokio::sync::mpsc;

pub async fn run_tui(app_state: AppState) -> Result<()> {
    let mut stdout = io::stdout();
    enable_raw_mode()?;
    execute!(stdout, EnterAlternateScreen)?;

    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let (event_sender, event_receiver) = mpsc::unbounded_channel();
    let event_handler = EventHandler::new(event_receiver);
    
    let mut app = App::new(app_state.clone(), event_sender.clone()).await;

    // Clone event_sender for the spawned task
    let event_sender_task = event_sender.clone();
    
    // Spawn event listener
    tokio::spawn(async move {
        loop {
            if let Ok(true) = event::poll(Duration::from_millis(100)) {
                if let Ok(event) = event::read() {
                    match event {
                        CrosstermEvent::Key(key) => {
                            if key.kind == KeyEventKind::Press {
                                if let Err(_) = event_sender_task.send(Event::Key(key)) {
                                    break;
                                }
                            }
                        }
                        CrosstermEvent::Resize(w, h) => {
                            if let Err(_) = event_sender_task.send(Event::Resize(w, h)) {
                                break;
                            }
                        }
                        _ => {}
                    }
                }
            }

            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    });

    // Spawn periodic refresh
    let refresh_sender = event_sender.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_millis(1000));
        loop {
            interval.tick().await;
            if let Err(_) = refresh_sender.send(Event::Tick) {
                break;
            }
        }
    });

    let result = run_app(&mut terminal, &mut app, event_handler).await;

    // Cleanup
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    result
}

async fn run_app<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
    mut event_handler: EventHandler,
) -> Result<()> {
    loop {
        terminal.draw(|frame| {
            if let Err(e) = ui::render(frame, app) {
                eprintln!("Render error: {}", e);
            }
        })?;

        if let Some(event) = event_handler.next().await {
            if let Err(e) = app.handle_event(event).await {
                eprintln!("Event handling error: {}", e);
            }

            if app.should_quit() {
                break;
            }
        }
    }

    Ok(())
}