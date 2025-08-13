use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Cluster {
    pub id: Uuid,
    pub name: String,
    pub environment: String,
    pub cluster_type: String,
    pub region: Option<String>,
    pub zone: Option<String>,
    pub node_count: i32,
    pub node_size: String,
    pub status: String,
    pub cost_budget: Option<rust_decimal::Decimal>,
    pub cost_threshold: Option<i32>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Trace {
    pub id: Uuid,
    pub cluster_id: Option<Uuid>,
    pub trace_id: String,
    pub span_id: String,
    pub parent_span_id: Option<String>,
    pub operation_name: String,
    pub service_name: String,
    pub start_time: DateTime<Utc>,
    pub end_time: Option<DateTime<Utc>>,
    pub duration_ms: Option<i64>,
    pub status: String,
    pub error_message: Option<String>,
    pub tags: serde_json::Value,
    pub logs: serde_json::Value,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandExecution {
    pub id: Uuid,
    pub cluster_id: Option<Uuid>,
    pub command: String,
    pub script_name: Option<String>,
    pub arguments: serde_json::Value,
    pub exit_code: Option<i32>,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
    pub start_time: DateTime<Utc>,
    pub end_time: Option<DateTime<Utc>>,
    pub duration_ms: Option<i64>,
    pub user_id: Option<String>,
    pub session_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct DatabaseClient {
    pool: PgPool,
}

impl DatabaseClient {
    pub async fn new(database_url: &str) -> Result<Self> {
        let pool = PgPool::connect(database_url)
            .await
            .context("Failed to connect to PostgreSQL")?;

        // Run migrations
        sqlx::migrate!("../database/migrations")
            .run(&pool)
            .await
            .context("Failed to run migrations")?;

        Ok(Self { pool })
    }

    pub async fn insert_cluster(&self, cluster: &Cluster) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO clusters (id, name, environment, cluster_type, region, zone, 
                                node_count, node_size, status, cost_budget, cost_threshold)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            ON CONFLICT (name) DO UPDATE SET
                environment = $3,
                cluster_type = $4,
                region = $5,
                zone = $6,
                node_count = $7,
                node_size = $8,
                status = $9,
                cost_budget = $10,
                cost_threshold = $11,
                updated_at = NOW()
            "#,
            cluster.id,
            cluster.name,
            cluster.environment,
            cluster.cluster_type,
            cluster.region,
            cluster.zone,
            cluster.node_count,
            cluster.node_size,
            cluster.status,
            cluster.cost_budget,
            cluster.cost_threshold
        )
        .execute(&self.pool)
        .await
        .context("Failed to insert cluster")?;

        Ok(())
    }

    pub async fn get_clusters(&self) -> Result<Vec<Cluster>> {
        let clusters = sqlx::query_as!(
            Cluster,
            "SELECT * FROM clusters ORDER BY created_at DESC"
        )
        .fetch_all(&self.pool)
        .await
        .context("Failed to fetch clusters")?;

        Ok(clusters)
    }

    pub async fn get_cluster_by_name(&self, name: &str) -> Result<Option<Cluster>> {
        let cluster = sqlx::query_as!(
            Cluster,
            "SELECT * FROM clusters WHERE name = $1",
            name
        )
        .fetch_optional(&self.pool)
        .await
        .context("Failed to fetch cluster by name")?;

        Ok(cluster)
    }

    pub async fn insert_trace(&self, trace: &Trace) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO traces (id, cluster_id, trace_id, span_id, parent_span_id,
                              operation_name, service_name, start_time, end_time,
                              duration_ms, status, error_message, tags, logs)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            "#,
            trace.id,
            trace.cluster_id,
            trace.trace_id,
            trace.span_id,
            trace.parent_span_id,
            trace.operation_name,
            trace.service_name,
            trace.start_time,
            trace.end_time,
            trace.duration_ms,
            trace.status,
            trace.error_message,
            trace.tags,
            trace.logs
        )
        .execute(&self.pool)
        .await
        .context("Failed to insert trace")?;

        Ok(())
    }

    pub async fn insert_command_execution(&self, execution: &CommandExecution) -> Result<Uuid> {
        let row = sqlx::query!(
            r#"
            INSERT INTO command_executions (id, cluster_id, command, script_name, arguments,
                                          exit_code, stdout, stderr, start_time, end_time,
                                          duration_ms, user_id, session_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING id
            "#,
            execution.id,
            execution.cluster_id,
            execution.command,
            execution.script_name,
            execution.arguments,
            execution.exit_code,
            execution.stdout,
            execution.stderr,
            execution.start_time,
            execution.end_time,
            execution.duration_ms,
            execution.user_id,
            execution.session_id
        )
        .fetch_one(&self.pool)
        .await
        .context("Failed to insert command execution")?;

        Ok(row.id)
    }

    pub async fn update_command_execution(&self, id: Uuid, exit_code: i32, stdout: &str, stderr: &str, end_time: DateTime<Utc>) -> Result<()> {
        let duration_ms = sqlx::query!(
            r#"
            UPDATE command_executions 
            SET exit_code = $2, stdout = $3, stderr = $4, end_time = $5,
                duration_ms = EXTRACT(EPOCH FROM ($5 - start_time)) * 1000
            WHERE id = $1
            RETURNING duration_ms
            "#,
            id,
            exit_code,
            stdout,
            stderr,
            end_time
        )
        .fetch_one(&self.pool)
        .await
        .context("Failed to update command execution")?;

        Ok(())
    }

    pub async fn get_recent_traces(&self, cluster_id: Option<Uuid>, limit: i64) -> Result<Vec<Trace>> {
        let traces = match cluster_id {
            Some(id) => {
                sqlx::query_as!(
                    Trace,
                    "SELECT * FROM traces WHERE cluster_id = $1 ORDER BY start_time DESC LIMIT $2",
                    id, limit
                )
                .fetch_all(&self.pool)
                .await
            }
            None => {
                sqlx::query_as!(
                    Trace,
                    "SELECT * FROM traces ORDER BY start_time DESC LIMIT $1",
                    limit
                )
                .fetch_all(&self.pool)
                .await
            }
        }
        .context("Failed to fetch recent traces")?;

        Ok(traces)
    }

    pub async fn get_command_executions(&self, cluster_id: Option<Uuid>, limit: i64) -> Result<Vec<CommandExecution>> {
        let executions = match cluster_id {
            Some(id) => {
                sqlx::query_as!(
                    CommandExecution,
                    "SELECT * FROM command_executions WHERE cluster_id = $1 ORDER BY start_time DESC LIMIT $2",
                    id, limit
                )
                .fetch_all(&self.pool)
                .await
            }
            None => {
                sqlx::query_as!(
                    CommandExecution,
                    "SELECT * FROM command_executions ORDER BY start_time DESC LIMIT $1",
                    limit
                )
                .fetch_all(&self.pool)
                .await
            }
        }
        .context("Failed to fetch command executions")?;

        Ok(executions)
    }

    pub async fn get_cluster_summary(&self) -> Result<Vec<HashMap<String, serde_json::Value>>> {
        let rows = sqlx::query("SELECT * FROM cluster_summary")
            .fetch_all(&self.pool)
            .await
            .context("Failed to fetch cluster summary")?;

        let mut results = Vec::new();
        for row in rows {
            let mut map = HashMap::new();
            for (i, column) in row.columns().iter().enumerate() {
                let value: serde_json::Value = row.try_get(i).unwrap_or(serde_json::Value::Null);
                map.insert(column.name().to_string(), value);
            }
            results.push(map);
        }

        Ok(results)
    }
}