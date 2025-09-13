type CloudType = "gcp" | "aws" | "azure"
type GitopsType = "argo" | "flux"
type AreaType = "ireland" | "london" | "frankfurt" | "paris" | "stockholm" | "zurich" | "tel-aviv"

type RegionType = "europe-west1" | "europe-west2" | "europe-west3" | "europe-west9" | "europe-north1" | "europe-west6" | "me-west1" | "eu-west-1" | "eu-west-2" | "eu-central-1" | "eu-west-3" | "eu-north-1" | "eu-central-2" | "il-central-1" | "west-europe" | "uk-south" | "germany-west-central" | "france-central" | "sweden-central" | "switzerland-north" | "israel-central"

type DatabaseType = "postgres" | "mysql" | "redis" | "influxdb" | "mongodb" | "neo4j" | "arangoDB"

type Registry = "ecr" | "gar" | "local"
type Apps = "dapr" | "external-secrets" | "crossplane"