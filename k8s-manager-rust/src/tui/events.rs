use crossterm::event::KeyEvent;
use tokio::sync::mpsc::UnboundedReceiver;

#[derive(Debug, Clone)]
pub enum Event {
    Key(KeyEvent),
    Resize(u16, u16),
    Tick,
}

pub struct EventHandler {
    receiver: UnboundedReceiver<Event>,
}

impl EventHandler {
    pub fn new(receiver: UnboundedReceiver<Event>) -> Self {
        Self { receiver }
    }

    pub async fn next(&mut self) -> Option<Event> {
        self.receiver.recv().await
    }
}