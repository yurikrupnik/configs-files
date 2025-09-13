import gitops
import config

# import manifests
_apps: [gitops.App] = option("applications") or []
_enabled_applications = [app for app in _apps if app.enabled]
# Output only the resources as items
items = gitops.get_gitops_resources(config._config.gitops, _enabled_applications)
#manifests.yaml_stream(_items)
