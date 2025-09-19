use axum::{
    body::Body,
    http::{Request, Response, StatusCode},
    middleware::Next,
    response::IntoResponse,
};
use tower::{Layer, Service};
use std::{
    future::Future,
    pin::Pin,
    task::{Context, Poll},
    time::Instant,
};

#[derive(Clone)]
pub struct RequestLoggingLayer;

impl<S> Layer<S> for RequestLoggingLayer {
    type Service = RequestLoggingMiddleware<S>;

    fn layer(&self, inner: S) -> Self::Service {
        RequestLoggingMiddleware { inner }
    }
}

#[derive(Clone)]
pub struct RequestLoggingMiddleware<S> {
    inner: S,
}

impl<S> Service<Request<Body>> for RequestLoggingMiddleware<S>
where
    S: Service<Request<Body>, Response = Response<Body>> + Send + 'static,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, request: Request<Body>) -> Self::Future {
        let start = Instant::now();
        let method = request.method().clone();
        let uri = request.uri().clone();
        let version = request.version();
        let _headers = request.headers().clone();

        let future = self.inner.call(request);

        Box::pin(async move {
            let response = future.await?;
            let elapsed = start.elapsed();
            
            tracing::info!(
                method = %method,
                uri = %uri,
                version = ?version,
                status = %response.status(),
                elapsed = ?elapsed,
                "HTTP request processed"
            );

            Ok(response)
        })
    }
}

pub async fn auth_middleware(
    request: Request<Body>,
    next: Next,
) -> Result<Response<Body>, StatusCode> {
    // Simple auth middleware - in production, implement proper authentication
    if let Some(auth_header) = request.headers().get("Authorization") {
        if let Ok(auth_str) = auth_header.to_str() {
            if auth_str.starts_with("Bearer ") {
                // Validate token here
                return Ok(next.run(request).await);
            }
        }
    }

    // For now, allow all requests
    Ok(next.run(request).await)
}

pub async fn cors_middleware(
    request: Request<Body>,
    next: Next,
) -> impl IntoResponse {
    let response = next.run(request).await;
    
    // Add CORS headers
    let mut response = response.into_response();
    let headers = response.headers_mut();
    
    headers.insert("Access-Control-Allow-Origin", "*".parse().unwrap());
    headers.insert("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS".parse().unwrap());
    headers.insert("Access-Control-Allow-Headers", "Content-Type, Authorization".parse().unwrap());
    
    response
}

pub async fn error_handler(
    request: Request<Body>,
    next: Next,
) -> Result<Response<Body>, StatusCode> {
    match next.run(request).await.into_response() {
        response if response.status().is_success() => Ok(response.into()),
        response => {
            tracing::error!("Request failed with status: {}", response.status());
            Ok(response.into())
        }
    }
}