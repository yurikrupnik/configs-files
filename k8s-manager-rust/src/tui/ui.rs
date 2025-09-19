use super::app::{App, TabIndex, ResourceTab, InputMode};
use crate::ResourceState;
use ratatui::{
    backend::Backend,
    layout::{Constraint, Direction, Layout, Rect, Alignment},
    style::{Color, Modifier, Style},
    symbols,
    text::{Line, Span, Text},
    widgets::{
        Block, Borders, Clear, Gauge, List, ListItem, ListState, Paragraph, Tabs,
        Table, Row, Cell, TableState, Wrap
    },
    Frame,
};

pub fn render(frame: &mut ratatui::Frame, app: &App) -> crate::Result<()> {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Min(0),    // Content
            Constraint::Length(3), // Footer
        ])
        .split(frame.size());

    render_header(frame, chunks[0], app);
    render_content(frame, chunks[1], app);
    render_footer(frame, chunks[2], app);

    if app.show_help {
        render_help_popup(frame, app);
    }

    Ok(())
}

fn render_header(frame: &mut ratatui::Frame, area: Rect, app: &App) {
    let tabs = vec!["Overview", "Resources", "Events", "Metrics", "Settings"];
    let selected = match app.current_tab {
        TabIndex::Overview => 0,
        TabIndex::Resources => 1,
        TabIndex::Events => 2,
        TabIndex::Metrics => 3,
        TabIndex::Settings => 4,
    };

    let tabs_widget = Tabs::new(tabs)
        .block(Block::default().borders(Borders::ALL).title("🎛️ K8s Manager"))
        .select(selected)
        .style(Style::default().fg(Color::White))
        .highlight_style(Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD));

    frame.render_widget(tabs_widget, area);
}

fn render_content(frame: &mut ratatui::Frame, area: Rect, app: &App) {
    match app.current_tab {
        TabIndex::Overview => render_overview(frame, area, app),
        TabIndex::Resources => render_resources(frame, area, app),
        TabIndex::Events => render_events(frame, area, app),
        TabIndex::Metrics => render_metrics(frame, area, app),
        TabIndex::Settings => render_settings(frame, area, app),
    }
}

fn render_footer(frame: &mut ratatui::Frame, area: Rect, app: &App) {
    let mut footer_text = match app.input_mode {
        InputMode::Normal => vec![
            Span::raw("Press "),
            Span::styled("q", Style::default().fg(Color::Yellow)),
            Span::raw(" to quit, "),
            Span::styled("h", Style::default().fg(Color::Yellow)),
            Span::raw(" for help, "),
            Span::styled("f", Style::default().fg(Color::Yellow)),
            Span::raw(" to filter, "),
            Span::styled(":", Style::default().fg(Color::Yellow)),
            Span::raw(" for commands"),
        ],
        InputMode::Filtering => vec![
            Span::raw("Filter mode - "),
            Span::styled("Enter", Style::default().fg(Color::Green)),
            Span::raw(" to apply, "),
            Span::styled("Esc", Style::default().fg(Color::Red)),
            Span::raw(" to cancel"),
        ],
        InputMode::Command => vec![
            Span::raw("Command mode - "),
            Span::styled("Enter", Style::default().fg(Color::Green)),
            Span::raw(" to execute, "),
            Span::styled("Esc", Style::default().fg(Color::Red)),
            Span::raw(" to cancel"),
        ],
    };

    if let Some(ref message) = app.status_message {
        footer_text = vec![Span::styled(message, Style::default().fg(Color::Cyan))];
    }

    let footer = Paragraph::new(Line::from(footer_text))
        .block(Block::default().borders(Borders::ALL))
        .alignment(Alignment::Left);

    frame.render_widget(footer, area);
}

fn render_overview(frame: &mut ratatui::Frame, area: Rect, _app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(5),  // Metrics
            Constraint::Min(0),     // Resource summary
        ])
        .split(area);

    // Metrics bar
    let metrics_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(25),
            Constraint::Percentage(25),
            Constraint::Percentage(25),
            Constraint::Percentage(25),
        ])
        .split(chunks[0]);

    // This would need async access to metrics, simplified for now
    render_metric_gauge(frame, metrics_chunks[0], "Healthy", 85, Color::Green);
    render_metric_gauge(frame, metrics_chunks[1], "Warning", 10, Color::Yellow);
    render_metric_gauge(frame, metrics_chunks[2], "Error", 5, Color::Red);
    render_metric_gauge(frame, metrics_chunks[3], "Total", 100, Color::Blue);

    // Resource summary
    let summary_text = vec![
        Line::from("📊 Cluster Overview"),
        Line::from(""),
        Line::from(vec![
            Span::raw("• Resources: "),
            Span::styled("Loading...", Style::default().fg(Color::Cyan)),
        ]),
        Line::from(vec![
            Span::raw("• Namespaces: "),
            Span::styled("Loading...", Style::default().fg(Color::Cyan)),
        ]),
        Line::from(vec![
            Span::raw("• Last Update: "),
            Span::styled("Loading...", Style::default().fg(Color::Cyan)),
        ]),
    ];

    let summary = Paragraph::new(summary_text)
        .block(Block::default().borders(Borders::ALL).title("Cluster Summary"))
        .wrap(Wrap { trim: true });

    frame.render_widget(summary, chunks[1]);
}

fn render_resources(frame: &mut ratatui::Frame, area: Rect, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Resource type tabs
            Constraint::Min(0),    // Resource list
        ])
        .split(area);

    // Resource type tabs
    let resource_tabs = vec!["All", "Pods", "Services", "Deployments", "ConfigMaps", "Secrets"];
    let selected_tab = match app.resource_tab {
        ResourceTab::All => 0,
        ResourceTab::Pods => 1,
        ResourceTab::Services => 2,
        ResourceTab::Deployments => 3,
        ResourceTab::ConfigMaps => 4,
        ResourceTab::Secrets => 5,
    };

    let tabs_widget = Tabs::new(resource_tabs)
        .block(Block::default().borders(Borders::ALL))
        .select(selected_tab)
        .style(Style::default().fg(Color::White))
        .highlight_style(Style::default().fg(Color::Green).add_modifier(Modifier::BOLD));

    frame.render_widget(tabs_widget, chunks[0]);

    // Resource table
    let header = Row::new(vec!["Name", "Kind", "Namespace", "State", "Age"])
        .style(Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD))
        .height(1);

    // This would need async access to resources
    let rows: Vec<Row> = vec![
        Row::new(vec!["loading...", "", "", "", ""]),
    ];

    let table = Table::new(rows, [
            Constraint::Percentage(30),
            Constraint::Percentage(20),
            Constraint::Percentage(20),
            Constraint::Percentage(15),
            Constraint::Percentage(15),
        ])
        .header(header)
        .block(Block::default().borders(Borders::ALL).title("Resources"));

    frame.render_widget(table, chunks[1]);
}

fn render_events(frame: &mut ratatui::Frame, area: Rect, _app: &App) {
    let events: Vec<ListItem> = vec![
        ListItem::new("📝 Loading events..."),
    ];

    let events_list = List::new(events)
        .block(Block::default().borders(Borders::ALL).title("Recent Events"))
        .highlight_style(Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD));

    frame.render_widget(events_list, area);
}

fn render_metrics(frame: &mut ratatui::Frame, area: Rect, _app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage(50),
            Constraint::Percentage(50),
        ])
        .split(area);

    // Resource distribution
    let resource_text = vec![
        Line::from("📊 Resource Distribution"),
        Line::from(""),
        Line::from("Loading metrics..."),
    ];

    let resource_metrics = Paragraph::new(resource_text)
        .block(Block::default().borders(Borders::ALL).title("Resource Metrics"))
        .wrap(Wrap { trim: true });

    frame.render_widget(resource_metrics, chunks[0]);

    // Event statistics
    let event_text = vec![
        Line::from("📈 Event Statistics"),
        Line::from(""),
        Line::from("Loading event data..."),
    ];

    let event_metrics = Paragraph::new(event_text)
        .block(Block::default().borders(Borders::ALL).title("Event Metrics"))
        .wrap(Wrap { trim: true });

    frame.render_widget(event_metrics, chunks[1]);
}

fn render_settings(frame: &mut ratatui::Frame, area: Rect, _app: &App) {
    let settings_text = vec![
        Line::from("⚙️ Configuration"),
        Line::from(""),
        Line::from(vec![
            Span::raw("Namespaces: "),
            Span::styled("default, kube-system", Style::default().fg(Color::Cyan)),
        ]),
        Line::from(vec![
            Span::raw("Resource Types: "),
            Span::styled("pods, services, deployments", Style::default().fg(Color::Cyan)),
        ]),
        Line::from(vec![
            Span::raw("Refresh Rate: "),
            Span::styled("1000ms", Style::default().fg(Color::Cyan)),
        ]),
        Line::from(""),
        Line::from("Press 'r' to refresh configuration"),
    ];

    let settings = Paragraph::new(settings_text)
        .block(Block::default().borders(Borders::ALL).title("Settings"))
        .wrap(Wrap { trim: true });

    frame.render_widget(settings, area);
}

fn render_metric_gauge(frame: &mut ratatui::Frame, area: Rect, title: &str, value: u16, color: Color) {
    let gauge = Gauge::default()
        .block(Block::default().borders(Borders::ALL).title(title))
        .gauge_style(Style::default().fg(color))
        .percent(value)
        .label(format!("{}%", value));

    frame.render_widget(gauge, area);
}

fn render_help_popup(frame: &mut ratatui::Frame, _app: &App) {
    let area = centered_rect(60, 70, frame.size());

    let help_text = vec![
        Line::from(vec![
            Span::styled("🎛️ K8s Manager Help", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD))
        ]),
        Line::from(""),
        Line::from("🗂️ Navigation:"),
        Line::from("  Tab/Shift+Tab   - Switch tabs"),
        Line::from("  1-5             - Direct tab access"),
        Line::from("  ↑/↓, j/k        - Scroll up/down"),
        Line::from("  ←/→, n/m        - Resource type tabs"),
        Line::from("  Enter           - Select item"),
        Line::from(""),
        Line::from("🔍 Filtering:"),
        Line::from("  f               - Enter filter mode"),
        Line::from("  ns:production   - Filter by namespace"),
        Line::from("  state:running   - Filter by state"),
        Line::from(""),
        Line::from("⚡ Commands:"),
        Line::from("  :               - Command mode"),
        Line::from("  :quit, :q       - Quit application"),
        Line::from("  :clear          - Clear events"),
        Line::from("  :refresh, :r    - Refresh data"),
        Line::from("  :export         - Export current state"),
        Line::from(""),
        Line::from("🔧 Actions:"),
        Line::from("  r               - Refresh data"),
        Line::from("  c               - Clear events (Events tab)"),
        Line::from("  d               - Show details"),
        Line::from("  h/F1            - Toggle help"),
        Line::from("  q/Esc           - Quit/Close"),
    ];

    let help_paragraph = Paragraph::new(help_text)
        .block(Block::default().borders(Borders::ALL).title("Help"))
        .wrap(Wrap { trim: true });

    frame.render_widget(Clear, area);
    frame.render_widget(help_paragraph, area);
}

fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}