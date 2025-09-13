import types
import cloud_config

schema Config:
    local: bool = True
    primary_cloud: types.CloudType = "gcp"
    secondary_cloud: types.CloudType = "aws"
    gitops: types.GitopsType = "flux"
    area: types.AreaType = "tel-aviv"
    db: types.DatabaseType = "postgres"
    region: types.RegionType = cloud_config._cloud_regions[primary_cloud][area]
    monitoring: bool = True
    observability: bool = True

_config: Config = option("config") or Config {}