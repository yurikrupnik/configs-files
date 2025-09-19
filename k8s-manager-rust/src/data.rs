use polars::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use chrono::{DateTime, Utc};

use crate::{
    state::{ResourceEvent, ResourceStateMachine, StateMetrics},
    Result,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataProcessor {
    storage_path: String,
    batch_size: usize,
    event_buffer: Vec<ResourceEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub timestamp: DateTime<Utc>,
    pub insights: Vec<Insight>,
    pub metrics: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Insight {
    pub insight_type: String,
    pub severity: String,
    pub message: String,
    pub recommendation: Option<String>,
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendAnalysis {
    pub resource_type: String,
    pub namespace: String,
    pub trend_direction: String, // "increasing", "decreasing", "stable"
    pub event_rate: f64,
    pub anomalies_detected: bool,
    pub confidence: f64,
}

impl DataProcessor {
    pub fn new(storage_path: String, batch_size: usize) -> Self {
        Self {
            storage_path,
            batch_size,
            event_buffer: Vec::new(),
        }
    }

    pub fn add_event(&mut self, event: ResourceEvent) {
        self.event_buffer.push(event);
        
        if self.event_buffer.len() >= self.batch_size {
            if let Err(e) = self.flush_events() {
                tracing::error!("Failed to flush events: {}", e);
            }
        }
    }

    pub fn flush_events(&mut self) -> Result<()> {
        if self.event_buffer.is_empty() {
            return Ok(());
        }

        let df = self.events_to_dataframe(&self.event_buffer)?;
        let filename = format!(
            "{}/events-{}.parquet",
            self.storage_path,
            chrono::Utc::now().format("%Y%m%d-%H%M%S")
        );

        // Ensure directory exists
        if let Some(parent) = std::path::Path::new(&filename).parent() {
            std::fs::create_dir_all(parent)?;
        }

        // Write to parquet
        let mut file = std::fs::File::create(&filename)?;
        ParquetWriter::new(&mut file).finish(&mut df.clone().collect()?)?;

        tracing::info!("Flushed {} events to {}", self.event_buffer.len(), filename);
        self.event_buffer.clear();
        Ok(())
    }

    fn events_to_dataframe(&self, events: &[ResourceEvent]) -> Result<LazyFrame> {
        let data: Vec<_> = events
            .iter()
            .map(|event| {
                (
                    event.id.to_string(),
                    event.timestamp.timestamp(),
                    event.event_type.severity().to_string(),
                    event.resource.kind.clone(),
                    event.resource.name.clone(),
                    event.resource.namespace.clone().unwrap_or_else(|| "default".to_string()),
                    event.current_state.to_string(),
                    event.previous_state.as_ref().map(|s| s.to_string()).unwrap_or_else(|| "None".to_string()),
                    event.resource.labels.len() as i32,
                    event.message.clone().unwrap_or_else(|| "".to_string()),
                )
            })
            .collect();

        let ids: Vec<String> = data.iter().map(|d| d.0.clone()).collect();
        let timestamps: Vec<i64> = data.iter().map(|d| d.1).collect();
        let severities: Vec<String> = data.iter().map(|d| d.2.clone()).collect();
        let kinds: Vec<String> = data.iter().map(|d| d.3.clone()).collect();
        let names: Vec<String> = data.iter().map(|d| d.4.clone()).collect();
        let namespaces: Vec<String> = data.iter().map(|d| d.5.clone()).collect();
        let current_states: Vec<String> = data.iter().map(|d| d.6.clone()).collect();
        let previous_states: Vec<String> = data.iter().map(|d| d.7.clone()).collect();
        let label_counts: Vec<i32> = data.iter().map(|d| d.8).collect();
        let messages: Vec<String> = data.iter().map(|d| d.9.clone()).collect();

        let df = DataFrame::new(vec![
            Series::new("id".into(), ids),
            Series::new("timestamp".into(), timestamps),
            Series::new("severity".into(), severities),
            Series::new("kind".into(), kinds),
            Series::new("name".into(), names),
            Series::new("namespace".into(), namespaces),
            Series::new("current_state".into(), current_states),
            Series::new("previous_state".into(), previous_states),
            Series::new("label_count".into(), label_counts),
            Series::new("message".into(), messages),
        ])?;

        Ok(df.lazy())
    }

    pub fn analyze_resource_health(&self, window_hours: i64) -> Result<AnalysisResult> {
        let pattern = format!("{}/events-*.parquet", self.storage_path);

        let df = LazyFrame::scan_parquet(pattern.into(), ScanArgsParquet::default())?
            .filter(
                col("timestamp").gt_eq(lit(
                    (chrono::Utc::now() - chrono::Duration::hours(window_hours)).timestamp()
                ))
            );

        // Group by namespace, kind, and name
        let health_summary = df
            .group_by([col("namespace"), col("kind"), col("name")])
            .agg([
                col("severity").count().alias("total_events"),
                col("severity")
                    .filter(col("severity").eq(lit("warning")).or(col("severity").eq(lit("error"))))
                    .count()
                    .alias("warning_count"),
                col("timestamp").max().alias("last_event"),
                col("current_state").last().alias("current_state"),
            ])
            .with_columns([
                (col("warning_count").cast(DataType::Float64) / col("total_events").cast(DataType::Float64) * lit(100.0))
                    .alias("warning_percentage")
            ])
            .sort(["warning_percentage"], SortMultipleOptions::default());

        let result_df = health_summary.collect()?;
        let mut insights = Vec::new();

        // Generate insights from the data
        if result_df.height() > 0 {
            let warning_percentages: Vec<f64> = result_df
                .column("warning_percentage")?
                .f64()?
                .into_iter()
                .filter_map(|v| v)
                .collect();

            let high_warning_count = warning_percentages.iter().filter(|&&p| p > 50.0).count();
            
            if high_warning_count > 0 {
                insights.push(Insight {
                    insight_type: "health".to_string(),
                    severity: "critical".to_string(),
                    message: format!("{} resources have high warning rates (>50%)", high_warning_count),
                    recommendation: Some("Investigate resource issues and review logs".to_string()),
                    data: Some(serde_json::json!({
                        "high_warning_resources": high_warning_count,
                        "threshold": 50.0
                    })),
                });
            }
        }

        Ok(AnalysisResult {
            timestamp: chrono::Utc::now(),
            insights,
            metrics: serde_json::json!({
                "total_resources_analyzed": result_df.height(),
                "analysis_window_hours": window_hours,
            }),
        })
    }

    pub fn analyze_usage_trends(&self, window_hours: i64) -> Result<Vec<TrendAnalysis>> {
        let pattern = format!("{}/events-*.parquet", self.storage_path);

        let df = LazyFrame::scan_parquet(pattern.into(), ScanArgsParquet::default())?
            .filter(
                col("timestamp").gt_eq(lit(
                    (chrono::Utc::now() - chrono::Duration::hours(window_hours)).timestamp()
                ))
            );

        // Group by resource type and namespace to analyze trends
        let trends = df
            .group_by([col("kind"), col("namespace")])
            .agg([
                col("id").count().alias("event_count"),
                col("timestamp").min().alias("first_event"),
                col("timestamp").max().alias("last_event"),
            ])
            .with_columns([
                (col("last_event") - col("first_event")).alias("time_span"),
                (col("event_count").cast(DataType::Float64) / lit(window_hours as f64 * 3600.0))
                    .alias("events_per_second"),
            ])
            .collect()?;

        let mut analyses = Vec::new();

        for row_idx in 0..trends.height() {
            let kind_value = trends.column("kind")?.get(row_idx)?;
            let namespace_value = trends.column("namespace")?.get(row_idx)?;
            let events_per_second_value = trends.column("events_per_second")?.get(row_idx)?;
            let event_count_value = trends.column("event_count")?.get(row_idx)?;
            
            let kind = kind_value.get_str().unwrap_or("unknown");
            let namespace = namespace_value.get_str().unwrap_or("default");
            let events_per_second = events_per_second_value.try_extract::<f64>().unwrap_or(0.0);
            let event_count = event_count_value.try_extract::<u32>().unwrap_or(0);

            let trend_direction = if events_per_second > 0.1 {
                "increasing"
            } else if events_per_second < 0.01 {
                "stable"
            } else {
                "moderate"
            };

            let anomalies_detected = events_per_second > 1.0; // More than 1 event per second
            let confidence = if event_count > 10 { 0.8 } else { 0.3 };

            analyses.push(TrendAnalysis {
                resource_type: kind.to_string(),
                namespace: namespace.to_string(),
                trend_direction: trend_direction.to_string(),
                event_rate: events_per_second,
                anomalies_detected,
                confidence,
            });
        }

        Ok(analyses)
    }

    pub fn detect_config_drift(
        &self,
        current_resources: &HashMap<String, ResourceStateMachine>,
        baseline_file: &str,
    ) -> Result<AnalysisResult> {
        // Load baseline from file
        let baseline_content = std::fs::read_to_string(baseline_file)?;
        let baseline: HashMap<String, serde_json::Value> = serde_json::from_str(&baseline_content)?;

        let mut insights = Vec::new();
        let mut drift_count = 0;

        for (key, machine) in current_resources {
            if let Some(baseline_resource) = baseline.get(key) {
                // Compare labels
                let baseline_labels = baseline_resource
                    .get("labels")
                    .and_then(|v| v.as_object())
                    .map(|obj| {
                        obj.iter()
                            .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                            .collect::<HashMap<_, _>>()
                    })
                    .unwrap_or_default();

                if machine.resource.labels != baseline_labels {
                    drift_count += 1;
                    insights.push(Insight {
                        insight_type: "drift".to_string(),
                        severity: "warning".to_string(),
                        message: format!("Labels changed for {}", key),
                        recommendation: Some("Review label changes for compliance".to_string()),
                        data: Some(serde_json::json!({
                            "resource": key,
                            "current_labels": machine.resource.labels,
                            "baseline_labels": baseline_labels,
                        })),
                    });
                }
            } else {
                drift_count += 1;
                insights.push(Insight {
                    insight_type: "drift".to_string(),
                    severity: "info".to_string(),
                    message: format!("New resource detected: {}", key),
                    recommendation: Some("Verify if this resource should be tracked".to_string()),
                    data: Some(serde_json::json!({
                        "resource": key,
                        "type": "new_resource",
                    })),
                });
            }
        }

        Ok(AnalysisResult {
            timestamp: chrono::Utc::now(),
            insights,
            metrics: serde_json::json!({
                "total_resources": current_resources.len(),
                "drift_detected": drift_count,
                "baseline_resources": baseline.len(),
            }),
        })
    }

    pub fn generate_compliance_report(
        &self,
        resources: &HashMap<String, ResourceStateMachine>,
        metrics: &StateMetrics,
    ) -> Result<AnalysisResult> {
        let mut insights = Vec::new();

        // Check for old resources (not updated in 24 hours)
        let old_threshold = chrono::Utc::now() - chrono::Duration::hours(24);
        let old_resources: Vec<_> = resources
            .iter()
            .filter(|(_, machine)| machine.last_updated < old_threshold)
            .collect();

        if !old_resources.is_empty() {
            insights.push(Insight {
                insight_type: "compliance".to_string(),
                severity: "warning".to_string(),
                message: format!("{} resources not updated in 24+ hours", old_resources.len()),
                recommendation: Some("Review stale resources for potential cleanup".to_string()),
                data: Some(serde_json::json!({
                    "stale_resources": old_resources.len(),
                    "threshold_hours": 24,
                })),
            });
        }

        // Check resource health ratio
        let total = metrics.total_resources.max(1);
        let unhealthy_percentage = (metrics.unhealthy_resources * 100) / total;
        
        if unhealthy_percentage > 10 {
            insights.push(Insight {
                insight_type: "compliance".to_string(),
                severity: "critical".to_string(),
                message: format!("{}% of resources are unhealthy", unhealthy_percentage),
                recommendation: Some("Investigate failed resources immediately".to_string()),
                data: Some(serde_json::json!({
                    "unhealthy_percentage": unhealthy_percentage,
                    "unhealthy_count": metrics.unhealthy_resources,
                    "total_count": metrics.total_resources,
                })),
            });
        }

        // Check for high event activity
        if metrics.events_last_hour > 200 {
            insights.push(Insight {
                insight_type: "compliance".to_string(),
                severity: "warning".to_string(),
                message: format!("High event activity: {} events in last hour", metrics.events_last_hour),
                recommendation: Some("Monitor for unusual cluster activity".to_string()),
                data: Some(serde_json::json!({
                    "events_last_hour": metrics.events_last_hour,
                    "threshold": 200,
                })),
            });
        }

        Ok(AnalysisResult {
            timestamp: chrono::Utc::now(),
            insights,
            metrics: serde_json::json!({
                "total_resources": metrics.total_resources,
                "healthy_resources": metrics.healthy_resources,
                "unhealthy_resources": metrics.unhealthy_resources,
                "events_analyzed": metrics.events_last_hour,
                "compliance_checks": 3,
            }),
        })
    }

    pub fn cleanup_old_data(&self, retention_days: u32) -> Result<usize> {
        let cutoff_date = chrono::Utc::now() - chrono::Duration::days(retention_days as i64);
        let mut deleted_files = 0;

        if let Ok(entries) = std::fs::read_dir(&self.storage_path) {
            for entry in entries.flatten() {
                if let Ok(metadata) = entry.metadata() {
                    if let Ok(modified) = metadata.modified() {
                        let modified_datetime = DateTime::<Utc>::from(modified);
                        if modified_datetime < cutoff_date {
                            if let Ok(()) = std::fs::remove_file(entry.path()) {
                                deleted_files += 1;
                                tracing::info!("Deleted old data file: {:?}", entry.path());
                            }
                        }
                    }
                }
            }
        }

        Ok(deleted_files)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_data_processor_creation() {
        let temp_dir = tempdir().unwrap();
        let processor = DataProcessor::new(temp_dir.path().to_string_lossy().to_string(), 10);
        assert_eq!(processor.batch_size, 10);
        assert!(processor.event_buffer.is_empty());
    }
}