use futures::TryStreamExt;
use k8s_openapi::api::core::v1::{Pod, Service, ConfigMap, Secret};
use k8s_openapi::api::apps::v1::Deployment;
use kube::{
    api::{Api, WatchParams},
    runtime::{watcher, WatchStreamExt},
    runtime::watcher::Event as WatchEvent,
    Client, Resource,
};
use serde::de::DeserializeOwned;
use std::collections::HashMap;
use std::fmt::{Debug};
use anyhow::Result;
use std::hash::Hash;
use tokio::sync::broadcast;
use tracing::{error, info, warn};

use crate::{
    state::{EventType, K8sResource, ResourceEvent, ResourceState},
    AppState, Config,
};

pub struct K8sWatcher {
    client: Client,
    config: Config,
    event_sender: broadcast::Sender<ResourceEvent>,
}

impl K8sWatcher {
    pub async fn new(config: Config) -> Result<Self> {
        let client = Client::try_default().await?;
        let (event_sender, _) = broadcast::channel(1000);

        Ok(Self {
            client,
            config,
            event_sender,
        })
    }

    pub fn subscribe(&self) -> broadcast::Receiver<ResourceEvent> {
        self.event_sender.subscribe()
    }

    pub async fn start(&self, app_state: AppState) -> Result<()> {
        info!("Starting Kubernetes watchers...");

        let mut handles = Vec::new();

        // Start watchers for each namespace and resource type
        for namespace in &self.config.watcher.namespaces {
            for resource_type in &self.config.watcher.resource_types {
                let handle = self.start_resource_watcher(
                    namespace.clone(),
                    resource_type.clone(),
                    app_state.clone(),
                ).await?;
                handles.push(handle);
            }
        }

        // Wait for all watchers
        futures::future::join_all(handles).await;
        Ok(())
    }

    async fn start_resource_watcher(
        &self,
        namespace: String,
        resource_type: String,
        app_state: AppState,
    ) -> Result<tokio::task::JoinHandle<()>> {
        let client = self.client.clone();
        let event_sender = self.event_sender.clone();
        let config = self.config.clone();

        let handle = tokio::spawn(async move {
            loop {
                match Self::watch_resource_type(
                    &client,
                    &namespace,
                    &resource_type,
                    &config,
                    &event_sender,
                    &app_state,
                ).await {
                    Ok(_) => {
                        warn!("Watcher for {}/{} completed unexpectedly", namespace, resource_type);
                    }
                    Err(e) => {
                        error!("Watcher error for {}/{}: {}", namespace, resource_type, e);
                    }
                }

                // Wait before reconnecting
                tokio::time::sleep(tokio::time::Duration::from_millis(config.watcher.reconnect_interval)).await;
                info!("Reconnecting watcher for {}/{}", namespace, resource_type);
            }
        });

        Ok(handle)
    }

    async fn watch_resource_type(
        client: &Client,
        namespace: &str,
        resource_type: &str,
        config: &Config,
        event_sender: &broadcast::Sender<ResourceEvent>,
        app_state: &AppState,
    ) -> Result<()> {
        let watch_params = WatchParams::default();

        match resource_type {
            "pods" => {
                Self::watch_pods(client, namespace, event_sender, app_state).await
            }
            // TODO: Implement specific watchers for other resource types
            // "services" => {
            //     Self::watch_resources::<Service>(client, namespace, watch_params, event_sender, app_state).await
            // }
            // "deployments" => {
            //     Self::watch_resources::<Deployment>(client, namespace, watch_params, event_sender, app_state).await
            // }
            // "configmaps" => {
            //     Self::watch_configmaps::<ConfigMap>(client, namespace, watch_params, event_sender, app_state).await
            // }
            // "secrets" => {
            //     Self::watch_resources::<Secret>(client, namespace, watch_params, event_sender, app_state).await
            // }
            _ => {
                warn!("Unsupported resource type: {}", resource_type);
                Ok(())
            }
        }
    }

    // async fn watch_configmaps( client: &Client,
    //                            namespace: &str,
    //                            event_sender: &broadcast::Sender<ResourceEvent>,
    //                            app_state: &AppState) -> Result<()> {
    //     let api: Api<ConfigMap> = Api::namespaced(client.clone(), namespace);
    //     let config = kube::runtime::watcher::Config::default();
    //     let stream = watcher(api, config);
    //     tokio::pin!(stream);
    //
    //     Ok(())
    // }
    async fn watch_pods(
        client: &Client,
        namespace: &str,
        event_sender: &broadcast::Sender<ResourceEvent>,
        app_state: &AppState,
    ) -> Result<()> {
        let api: Api<Pod> = Api::namespaced(client.clone(), namespace);
        let config = kube::runtime::watcher::Config::default();
        let stream = watcher(api, config);

        tokio::pin!(stream);

        while let Some(event) = stream.try_next().await? {
            match event {
                WatchEvent::Applied(resource) => {
                    if let Ok(k8s_resource) = Self::convert_pod_to_k8s_resource(&resource) {
                        let event = ResourceEvent {
                            id: uuid::Uuid::new_v4(),
                            timestamp: chrono::Utc::now(),
                            event_type: EventType::Modified,
                            resource: k8s_resource,
                            previous_state: None,
                            current_state: Self::determine_pod_state(&resource),
                            message: None,
                        };

                        // Send to state manager
                        {
                            let mut state = app_state.state_manager.write().await;
                            if let Err(e) = state.process_event(event.clone()) {
                                error!("Failed to process event: {}", e);
                            }
                        }

                        // Broadcast event
                        if let Err(e) = event_sender.send(event) {
                            warn!("Failed to broadcast event: {}", e);
                        }
                    }
                }
                WatchEvent::Deleted(resource) => {
                    if let Ok(k8s_resource) = Self::convert_pod_to_k8s_resource(&resource) {
                        let event = ResourceEvent {
                            id: uuid::Uuid::new_v4(),
                            timestamp: chrono::Utc::now(),
                            event_type: EventType::Deleted,
                            resource: k8s_resource,
                            previous_state: None,
                            current_state: ResourceState::Terminating,
                            message: Some("Resource deleted".to_string()),
                        };

                        // Send to state manager
                        {
                            let mut state = app_state.state_manager.write().await;
                            if let Err(e) = state.process_event(event.clone()) {
                                error!("Failed to process event: {}", e);
                            }
                        }

                        // Broadcast event
                        if let Err(e) = event_sender.send(event) {
                            warn!("Failed to broadcast event: {}", e);
                        }
                    }
                }
                WatchEvent::Restarted(resources) => {
                    info!("Watch stream restarted for pods with {} resources", 
                         resources.len());
                    
                    // Re-process all resources
                    for resource in resources {
                        if let Ok(k8s_resource) = Self::convert_pod_to_k8s_resource(&resource) {
                            let event = ResourceEvent {
                                id: uuid::Uuid::new_v4(),
                                timestamp: chrono::Utc::now(),
                                event_type: EventType::Modified,
                                resource: k8s_resource,
                                previous_state: None,
                                current_state: Self::determine_pod_state(&resource),
                                message: Some("Resource reloaded after watch restart".to_string()),
                            };

                            // Send to state manager
                            {
                                let mut state = app_state.state_manager.write().await;
                                if let Err(e) = state.process_event(event.clone()) {
                                    error!("Failed to process restart event: {}", e);
                                }
                            }

                            // Broadcast event
                            if let Err(e) = event_sender.send(event) {
                                warn!("Failed to broadcast restart event: {}", e);
                            }
                        }
                    }
                }
            }
        }

        Ok(())
    }

    fn convert_pod_to_k8s_resource(resource: &Pod) -> Result<K8sResource> {
        let resource_json = serde_json::to_value(resource)?;
        
        let metadata = resource_json.get("metadata").ok_or_else(|| {
            crate::error::K8sManagerError::ResourceNotFound("Missing metadata".to_string())
        })?;

        let name = metadata.get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let namespace = metadata.get("namespace")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let uid = metadata.get("uid")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let resource_version = metadata.get("resourceVersion")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let labels = metadata.get("labels")
            .and_then(|v| v.as_object())
            .map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                    .collect()
            })
            .unwrap_or_default();

        let annotations = metadata.get("annotations")
            .and_then(|v| v.as_object())
            .map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                    .collect()
            })
            .unwrap_or_default();

        Ok(K8sResource {
            api_version: "v1".to_string(),
            kind: "Pod".to_string(),
            namespace,
            name,
            uid,
            resource_version,
            labels,
            annotations,
            spec: resource_json.get("spec").cloned(),
            status: resource_json.get("status").cloned(),
        })
    }

    fn convert_to_k8s_resource<K>(resource: &K) -> Result<K8sResource>
    where
        K: Resource + serde::Serialize,
        K::DynamicType: Default,
    {
        // This is a simplified conversion - in practice, you'd need more specific logic
        // for each resource type to extract the relevant information
        let resource_json = serde_json::to_value(resource)?;
        
        let metadata = resource_json.get("metadata").ok_or_else(|| {
            crate::error::K8sManagerError::ResourceNotFound("Missing metadata".to_string())
        })?;

        let name = metadata.get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let namespace = metadata.get("namespace")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let uid = metadata.get("uid")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let resource_version = metadata.get("resourceVersion")
            .and_then(|v| v.as_str())
            .unwrap_or("0")
            .to_string();

        let labels = metadata.get("labels")
            .and_then(|v| v.as_object())
            .map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                    .collect()
            })
            .unwrap_or_default();

        let annotations = metadata.get("annotations")
            .and_then(|v| v.as_object())
            .map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                    .collect()
            })
            .unwrap_or_default();

        Ok(K8sResource {
            api_version: K::api_version(&Default::default()).to_string(),
            kind: K::kind(&Default::default()).to_string(),
            namespace,
            name,
            uid,
            resource_version,
            labels,
            annotations,
            spec: resource_json.get("spec").cloned(),
            status: resource_json.get("status").cloned(),
        })
    }

    fn determine_pod_state(resource: &Pod) -> ResourceState {
        if let Some(status) = &resource.status {
            if let Some(phase) = &status.phase {
                return match phase.as_str() {
                    "Pending" => ResourceState::Pending,
                    "Running" => ResourceState::Running,
                    "Succeeded" => ResourceState::Succeeded,
                    "Failed" => ResourceState::Failed,
                    _ => ResourceState::Unknown,
                };
            }
        }
        ResourceState::Unknown
    }

    fn determine_resource_state<K>(resource: &K) -> ResourceState
    where
        K: Resource + serde::Serialize,
        K::DynamicType: Default,
    {
        let binding = Default::default();
        let kind = K::kind(&binding);
        let resource_json = serde_json::to_value(resource).unwrap_or_default();
        
        match kind.as_ref() {
            "Pod" => {
                if let Some(status) = resource_json.get("status") {
                    if let Some(phase) = status.get("phase").and_then(|v| v.as_str()) {
                        return match phase {
                            "Pending" => ResourceState::Pending,
                            "Running" => ResourceState::Running,
                            "Succeeded" => ResourceState::Succeeded,
                            "Failed" => ResourceState::Failed,
                            _ => ResourceState::Unknown,
                        };
                    }
                }
                ResourceState::Unknown
            }
            "Deployment" => {
                if let Some(status) = resource_json.get("status") {
                    let replicas = status.get("replicas").and_then(|v| v.as_u64()).unwrap_or(0);
                    let ready_replicas = status.get("readyReplicas").and_then(|v| v.as_u64()).unwrap_or(0);
                    let updated_replicas = status.get("updatedReplicas").and_then(|v| v.as_u64()).unwrap_or(0);

                    if ready_replicas == replicas && updated_replicas == replicas && replicas > 0 {
                        ResourceState::Running
                    } else if ready_replicas == 0 {
                        ResourceState::Pending
                    } else {
                        ResourceState::Running // Partial deployment
                    }
                } else {
                    ResourceState::Pending
                }
            }
            "Service" | "ConfigMap" | "Secret" => {
                // These resources are typically either present or not
                ResourceState::Running
            }
            _ => ResourceState::Unknown,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_watcher_creation() {
        let config = Config::default();
        let watcher = K8sWatcher::new(config).await;
        assert!(watcher.is_ok());
    }
}
