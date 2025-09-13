import types
import cloud_config
import fluxcd_source_controller.v1 as fluxSrc
import fluxcd_helm_controller.v2beta1 as flc
import fluxcd_kustomize_controller.v1 as fluxKust
import argo_cd.v1alpha1 as argoV1
import k8s.api.apps.v1 as apps
import k8s.api.core.v1 as core
import k8s.api.networking.v1 as networking
import k8s.apimachinery.pkg.apis.meta.v1 as metav1
import k8s.api.rbac.v1 as rbac
import k8s.api.batch.v1 as batch

schema App:
    name: str
    service: fluxSrc.GitRepository
    enabled: bool = True
    repo_url?: str
    path: str = "."
    namespace: str
    chart?: str
    helm_repo?: str
    target_revision: str = "HEAD"
    auto_sync: bool = True
    prune: bool = True
    self_heal: bool = True
    sync_wave: int = 0
    depends_on: [str] = []


_create_flux_git_repository = lambda app: App -> fluxSrc.GitRepository {
    fluxSrc.GitRepository {
        metadata = {
            name = app.name
            namespace = app.namespace
        }
        spec = {
            interval = "5m0s"
            url = app.repo_url
            ref = {
                branch = "master" if app.target_revision == "HEAD" else app.target_revision
            }
        }
    }
}

_create_flux_helm_repository = lambda app: App -> fluxSrc.HelmRepository {
    fluxSrc.HelmRepository {
        metadata = {
            name = app.name
            namespace = app.namespace
        }
        spec = {
            interval = "60m0s"
            url = app.helm_repo
        }
    }
}

_create_flux_helm_release = lambda app: App -> flc.HelmRelease {
    flc.HelmRelease {
        metadata = {
            name = app.name
            namespace = app.namespace
        }
        spec = {
            interval = "5m0s"
            dependsOn = [{"name" = dep} for dep in app.depends_on] if app.depends_on else []
            chart = {
                spec = {
                    chart = app.chart
                    version = app.target_revision if app.target_revision != "HEAD" else "*"
                    sourceRef = {
                        kind = "HelmRepository"
                        name = app.name
                        namespace = app.namespace
                    }
                }
            }
        }
    }

}

get_gitops_resources = lambda gitops_type: str, apps: [App] -> [any] {
    """
    Generate GitOps resources based on the gitops type and applications
    """
    _helm_repos = [_create_flux_helm_repository(app) for app in apps if app.helm_repo] if gitops_type == "flux" else []
    _helm_releases = [_create_flux_helm_release(app) for app in apps if app.helm_repo] if gitops_type == "flux" else []
    _git_repos = [_create_flux_git_repository(app) for app in apps if app.repo_url and not app.helm_repo] if gitops_type == "flux" else []
    _helm_repos + _helm_releases + _git_repos
}
