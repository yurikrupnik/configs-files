#!/usr/bin/env nu

# PostgreSQL database management for Kubernetes environments
# Supports both local (Kind) and cloud clusters

const DB_PROVIDERS = {
    postgresql: "postgresql",
    cockroachdb: "cockroachdb"
}

const PROVIDER_VALUES = [$DB_PROVIDERS.postgresql, $DB_PROVIDERS.cockroachdb]

# Validate database provider
def validate-db-provider [provider: string] {
    if $provider not-in $PROVIDER_VALUES {
        let options = ($PROVIDER_VALUES | str join ", ")
        error make {msg: $"Invalid database provider: ($provider). Valid options: ($options)"}
    }
}

# Check if running on macOS with sufficient resources
def is-local-mac [] {
    let uname = (uname | get kernel-name)
    let memory_gb = if ($uname == "Darwin") {
        try {
            let memory_bytes = (sysctl -n hw.memsize | into int)
            ($memory_bytes / 1024 / 1024 / 1024)
        } catch {
            0
        }
    } else {
        0
    }
    
    ($uname == "Darwin") and ($memory_gb >= 64)
}

# Check if kubectl context exists and cluster is accessible
def cluster-exists [] {
    try {
        kubectl cluster-info --request-timeout=5s | complete | get exit_code | $in == 0
    } catch {
        false
    }
}

# Auto-create local cluster if needed
def ensure-local-cluster [] {
    if not (cluster-exists) {
        if (is-local-mac) {
            print "🏠 No cluster found. Creating local Kind cluster with high-performance config..."
            nu scripts/kc-cluster.nu --cloud local
        } else {
            error make {msg: "No Kubernetes cluster available and not running on supported local environment"}
        }
    } else {
        print "✅ Using existing Kubernetes cluster"
    }
}

# Deploy PostgreSQL with optimized configuration
def deploy-postgresql [
    --namespace: string = "database"
    --name: string = "postgres"
    --storage: string = "20Gi"
    --memory: string = "2Gi"
    --cpu: string = "1000m"
    --replicas: int = 1
] {
    print $"🐘 Deploying PostgreSQL with ($replicas) replicas..."
    
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    let postgresql_manifest = $"
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ($name)
  namespace: ($namespace)
spec:
  serviceName: ($name)
  replicas: ($replicas)
  selector:
    matchLabels:
      app: ($name)
  template:
    metadata:
      labels:
        app: ($name)
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: \"appdb\"
        - name: POSTGRES_USER
          value: \"postgres\"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ($name)-secret
              key: password
        - name: PGDATA
          value: \"/var/lib/postgresql/data/pgdata\"
        resources:
          requests:
            memory: ($memory)
            cpu: ($cpu)
          limits:
            memory: ($memory)
            cpu: ($cpu)
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [\"ReadWriteOnce\"]
      resources:
        requests:
          storage: ($storage)
---
apiVersion: v1
kind: Secret
metadata:
  name: ($name)-secret
  namespace: ($namespace)
type: Opaque
data:
  password: cG9zdGdyZXMxMjM=  # postgres123 base64 encoded
---
apiVersion: v1
kind: Service
metadata:
  name: ($name)
  namespace: ($namespace)
spec:
  selector:
    app: ($name)
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: ($name)-headless
  namespace: ($namespace)
spec:
  selector:
    app: ($name)
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
  clusterIP: None
"

    $postgresql_manifest | kubectl apply -f -
    
    print "⏳ Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l $"app=($name)" -n $namespace --timeout=300s
    
    print "✅ PostgreSQL deployed successfully!"
    print $"📊 Connection details:"
    print $"   Host: ($name).($namespace).svc.cluster.local"
    print $"   Port: 5432"
    print $"   Database: appdb"
    print $"   Username: postgres"
    print $"   Password: postgres123"
}

# Deploy CockroachDB for high availability
def deploy-cockroachdb [
    --namespace: string = "database"
    --name: string = "cockroachdb"
    --storage: string = "20Gi"
    --memory: string = "2Gi"
    --cpu: string = "1000m"
    --replicas: int = 3
] {
    print $"🪳 Deploying CockroachDB with ($replicas) replicas..."
    
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    let cockroach_manifest = $"
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ($name)
  namespace: ($namespace)
spec:
  serviceName: ($name)
  replicas: ($replicas)
  selector:
    matchLabels:
      app: ($name)
  template:
    metadata:
      labels:
        app: ($name)
    spec:
      containers:
      - name: cockroachdb
        image: cockroachdb/cockroach:v24.1.0
        ports:
        - containerPort: 26257
          name: grpc
        - containerPort: 8080
          name: http
        command:
        - \"/cockroach/cockroach\"
        - \"start\"
        - \"--logtostderr\"
        - \"--insecure\"
        - \"--advertise-host=$(hostname -f)\"
        - \"--http-addr=0.0.0.0\"
        - \"--join=($name)-0.($name).($namespace).svc.cluster.local,($name)-1.($name).($namespace).svc.cluster.local,($name)-2.($name).($namespace).svc.cluster.local\"
        - \"--cache=25%\"
        - \"--max-sql-memory=25%\"
        resources:
          requests:
            memory: ($memory)
            cpu: ($cpu)
          limits:
            memory: ($memory)
            cpu: ($cpu)
        volumeMounts:
        - name: cockroach-data
          mountPath: /cockroach/cockroach-data
        livenessProbe:
          httpGet:
            path: \"/health\"
            port: http
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: \"/health?ready=1\"
            port: http
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2
  volumeClaimTemplates:
  - metadata:
      name: cockroach-data
    spec:
      accessModes: [\"ReadWriteOnce\"]
      resources:
        requests:
          storage: ($storage)
---
apiVersion: v1
kind: Service
metadata:
  name: ($name)-public
  namespace: ($namespace)
spec:
  selector:
    app: ($name)
  ports:
  - name: grpc
    port: 26257
    targetPort: 26257
  - name: http
    port: 8080
    targetPort: 8080
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: ($name)
  namespace: ($namespace)
spec:
  selector:
    app: ($name)
  ports:
  - name: grpc
    port: 26257
    targetPort: 26257
  - name: http
    port: 8080
    targetPort: 8080
  clusterIP: None
"

    $cockroach_manifest | kubectl apply -f -
    
    print "⏳ Waiting for CockroachDB cluster to be ready..."
    kubectl wait --for=condition=ready pod -l $"app=($name)" -n $namespace --timeout=300s
    
    print "🔧 Initializing CockroachDB cluster..."
    kubectl exec -n $namespace $"($name)-0" -- /cockroach/cockroach init --insecure
    
    print "📊 Creating application database..."
    kubectl exec -n $namespace $"($name)-0" -- /cockroach/cockroach sql --insecure --execute="CREATE DATABASE IF NOT EXISTS appdb;"
    kubectl exec -n $namespace $"($name)-0" -- /cockroach/cockroach sql --insecure --execute="CREATE USER IF NOT EXISTS appuser WITH PASSWORD 'apppass123';"
    kubectl exec -n $namespace $"($name)-0" -- /cockroach/cockroach sql --insecure --execute="GRANT ALL ON DATABASE appdb TO appuser;"
    
    print "✅ CockroachDB cluster deployed successfully!"
    print $"📊 Connection details:"
    print $"   Host: ($name)-public.($namespace).svc.cluster.local"
    print $"   Port: 26257"
    print $"   Database: appdb"
    print $"   Username: appuser"
    print $"   Password: apppass123"
}

# Create database and tables
def create-database [
    --provider: string = "postgresql"
    --namespace: string = "database"
    --name: string
    --sql-file: string = ""
] {
    validate-db-provider $provider
    
    let service_name = if $provider == "postgresql" { 
        if ($name | is-empty) { "postgres" } else { $name }
    } else { 
        if ($name | is-empty) { "cockroachdb-public" } else { $name }
    }
    
    print $"🗃️  Setting up database schema using ($provider)..."
    
    let default_schema = if $provider == "postgresql" {
        "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
"
    } else {
        "
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    content STRING,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
"
    }
    
    let schema = if ($sql_file | is-empty) { 
        $default_schema 
    } else { 
        open $sql_file 
    }
    
    if $provider == "postgresql" {
        kubectl exec -n $namespace $"($service_name)-0" -it -- psql -U postgres -d appdb -c $schema
    } else {
        kubectl exec -n $namespace $"($service_name)-0" -- /cockroach/cockroach sql --insecure --database=appdb --execute=$schema
    }
    
    print "✅ Database schema created successfully!"
}

# Execute SQL queries
def exec-sql [
    query: string
    --provider: string = "postgresql"
    --namespace: string = "database"
    --name: string
    --database: string = "appdb"
] {
    validate-db-provider $provider
    
    let service_name = if $provider == "postgresql" { 
        if ($name | is-empty) { "postgres" } else { $name }
    } else { 
        if ($name | is-empty) { "cockroachdb-public" } else { $name }
    }
    
    print $"🔍 Executing SQL query on ($provider)..."
    
    if $provider == "postgresql" {
        kubectl exec -n $namespace $"($service_name)-0" -it -- psql -U postgres -d $database -c $query
    } else {
        kubectl exec -n $namespace $"($service_name)-0" -- /cockroach/cockroach sql --insecure --database=$database --execute=$query
    }
}

# Insert sample data
def insert-sample-data [
    --provider: string = "postgresql"
    --namespace: string = "database"
    --name: string
] {
    validate-db-provider $provider
    
    print "📝 Inserting sample data..."
    
    let insert_users = "INSERT INTO users (username, email) VALUES 
        ('alice', 'alice@example.com'),
        ('bob', 'bob@example.com'),
        ('charlie', 'charlie@example.com')
        ON CONFLICT (username) DO NOTHING;"
    
    let insert_posts = if $provider == "postgresql" {
        "INSERT INTO posts (title, content, user_id) 
         SELECT 'First Post', 'This is my first post!', u.id FROM users u WHERE u.username = 'alice'
         UNION ALL
         SELECT 'Hello World', 'Welcome to my blog', u.id FROM users u WHERE u.username = 'bob'
         ON CONFLICT DO NOTHING;"
    } else {
        "INSERT INTO posts (title, content, user_id) 
         SELECT 'First Post', 'This is my first post!', u.id FROM users u WHERE u.username = 'alice'
         UNION ALL
         SELECT 'Hello World', 'Welcome to my blog', u.id FROM users u WHERE u.username = 'bob';"
    }
    
    exec-sql $insert_users --provider $provider --namespace $namespace --name $name
    exec-sql $insert_posts --provider $provider --namespace $namespace --name $name
    
    print "✅ Sample data inserted successfully!"
}

# Get database status and connection info
def get-database-info [
    --provider: string = "postgresql"
    --namespace: string = "database"
    --name: string
] {
    validate-db-provider $provider
    
    let service_name = if $provider == "postgresql" { 
        if ($name | is-empty) { "postgres" } else { $name }
    } else { 
        if ($name | is-empty) { "cockroachdb-public" } else { $name }
    }
    
    print $"📊 Database Information - ($provider)"
    print "================================"
    
    kubectl get pods -n $namespace -l $"app=($service_name)"
    kubectl get services -n $namespace
    kubectl get pvc -n $namespace
    
    print "\n🔌 Connection Commands:"
    if $provider == "postgresql" {
        print $"kubectl exec -n ($namespace) ($service_name)-0 -it -- psql -U postgres -d appdb"
        print $"kubectl port-forward -n ($namespace) svc/($service_name) 5432:5432"
    } else {
        print $"kubectl exec -n ($namespace) ($service_name)-0 -- /cockroach/cockroach sql --insecure --database=appdb"
        print $"kubectl port-forward -n ($namespace) svc/($service_name) 26257:26257"
        print $"kubectl port-forward -n ($namespace) svc/($service_name) 8080:8080"
    }
}

# Main command dispatcher
def main [
    command: string
    --provider: string = "postgresql"
    --namespace: string = "database"
    --name: string = ""
    --storage: string = "20Gi"
    --memory: string = "2Gi"
    --cpu: string = "1000m"
    --replicas: int = 1
    --sql-file: string = ""
    --query: string = ""
    --database: string = "appdb"
] {
    # Ensure cluster exists
    ensure-local-cluster
    
    match $command {
        "deploy" => {
            validate-db-provider $provider
            if $provider == "postgresql" {
                deploy-postgresql --namespace $namespace --name (if ($name | is-empty) { "postgres" } else { $name }) --storage $storage --memory $memory --cpu $cpu --replicas $replicas
            } else {
                deploy-cockroachdb --namespace $namespace --name (if ($name | is-empty) { "cockroachdb" } else { $name }) --storage $storage --memory $memory --cpu $cpu --replicas $replicas
            }
        }
        "create-schema" => {
            create-database --provider $provider --namespace $namespace --name $name --sql-file $sql_file
        }
        "insert-sample" => {
            insert-sample-data --provider $provider --namespace $namespace --name $name
        }
        "exec" => {
            if ($query | is-empty) {
                error make {msg: "Query parameter is required for exec command"}
            }
            exec-sql $query --provider $provider --namespace $namespace --name $name --database $database
        }
        "info" => {
            get-database-info --provider $provider --namespace $namespace --name $name
        }
        "setup-full" => {
            validate-db-provider $provider
            if $provider == "postgresql" {
                deploy-postgresql --namespace $namespace --name (if ($name | is-empty) { "postgres" } else { $name }) --storage $storage --memory $memory --cpu $cpu --replicas $replicas
            } else {
                deploy-cockroachdb --namespace $namespace --name (if ($name | is-empty) { "cockroachdb" } else { $name }) --storage $storage --memory $memory --cpu $cpu --replicas $replicas
            }
            
            sleep 30sec
            create-database --provider $provider --namespace $namespace --name $name --sql-file $sql_file
            insert-sample-data --provider $provider --namespace $namespace --name $name
            get-database-info --provider $provider --namespace $namespace --name $name
        }
        _ => {
            print "📚 Database Management Commands:"
            print "  deploy          - Deploy database to Kubernetes"
            print "  create-schema   - Create database schema"
            print "  insert-sample   - Insert sample data"
            print "  exec            - Execute SQL query"
            print "  info            - Show database status and connection info"
            print "  setup-full      - Deploy database and setup complete environment"
            print ""
            print "🔧 Options:"
            print "  --provider      - Database provider (postgresql|cockroachdb) [default: postgresql]"
            print "  --namespace     - Kubernetes namespace [default: database]"
            print "  --name          - Database service name [default: postgres|cockroachdb]"
            print "  --storage       - Storage size [default: 20Gi]"
            print "  --memory        - Memory limit [default: 2Gi]"
            print "  --cpu           - CPU limit [default: 1000m]"
            print "  --replicas      - Number of replicas [default: 1 for postgres, 3 for cockroach]"
            print "  --sql-file      - SQL file to execute for schema creation"
            print "  --query         - SQL query to execute"
            print "  --database      - Database name [default: appdb]"
            print ""
            print "📋 Examples:"
            print "  nu database-management.nu setup-full --provider postgresql"
            print "  nu database-management.nu setup-full --provider cockroachdb --replicas 3"
            print "  nu database-management.nu exec --query \"SELECT * FROM users;\""
            print "  nu database-management.nu info --provider cockroachdb"
        }
    }
}