# KCL Nu Shell Tests → Testkube Conversion Guide

## 🎉 Conversion Complete!

Your KCL Nu shell tests have been successfully converted to a production-ready Testkube testing pipeline.

## 📁 File Structure

```
testkube/
├── 00-install-testkube.yaml        # Testkube installation and RBAC
├── 01-kcl-integration-tests.yaml   # Integration tests (converted from integration-test.nu)  
├── 02-kcl-e2e-tests.yaml          # E2E tests (converted from e2e-test.nu)
├── 03-kcl-test-suite.yaml         # Complete test suite orchestration
├── 04-environment-config.yaml      # Environment configs and optimized containers
└── 05-deployment-monitoring.yaml   # Deployment scripts and monitoring
```

## 🚀 Quick Start

### 1. Prerequisites
```bash
# Ensure you have kubectl and Helm installed
kubectl version --client
helm version
```

### 2. Install Testkube
```bash
# Add Testkube Helm repository
helm repo add testkube https://kubeshop.github.io/helm-charts
helm repo update

# Install Testkube
helm install testkube testkube/testkube \
  --namespace testkube \
  --create-namespace \
  --set testkube-dashboard.enabled=true
```

### 3. Deploy Your KCL Tests
```bash
# Navigate to testkube directory
cd testkube/

# Apply configurations in order
kubectl apply -f 00-install-testkube.yaml
kubectl apply -f 04-environment-config.yaml
kubectl apply -f 01-kcl-integration-tests.yaml
kubectl apply -f 02-kcl-e2e-tests.yaml
kubectl apply -f 03-kcl-test-suite.yaml
kubectl apply -f 05-deployment-monitoring.yaml
```

### 4. Update Repository URL
**IMPORTANT**: Update the Git repository URL in the YAML files:
```bash
# Find and replace with your actual repository
find testkube/ -name "*.yaml" -exec sed -i 's|https://github.com/your-org/configs-files|https://github.com/YOUR-USERNAME/YOUR-REPO|g' {} \;
```

## 🧪 Running Tests

### Individual Tests
```bash
# Run integration tests
kubectl testkube run test kcl-integration-tests -n testkube

# Run E2E tests
kubectl testkube run test kcl-e2e-tests -n testkube

# Run smoke test
kubectl testkube run test kcl-smoke-test -n testkube
```

### Complete Test Suite
```bash
# Run the full test suite
kubectl testkube run testsuite kcl-crossplane-complete-suite -n testkube
```

### View Results
```bash
# List all executions
kubectl testkube get executions -n testkube

# Get specific test results
kubectl testkube get execution EXECUTION_ID -n testkube

# Follow logs in real-time
kubectl testkube logs EXECUTION_ID -n testkube -f
```

## 📊 Accessing Dashboard

### Testkube Dashboard
```bash
# Port forward to access locally
kubectl port-forward -n testkube svc/testkube-dashboard 8080:8080

# Open in browser
open http://localhost:8080
```

### CLI Installation (Optional)
```bash
# Install Testkube CLI for easier management
curl -sSLf https://get.testkube.io | sh
testkube --help
```

## 🔍 Monitoring & Alerting

### Built-in Monitoring
- **Daily monitoring reports**: CronJob runs at 9 AM daily
- **Slack notifications**: Configure webhook in YAML files
- **Prometheus metrics**: Available if Prometheus is installed
- **Grafana dashboard**: Pre-configured dashboard for visualizing metrics

### Manual Monitoring
```bash
# Run monitoring script
kubectl create job --from=cronjob/kcl-test-monitoring manual-monitor -n testkube
kubectl logs job/manual-monitor -n testkube
```

## ⚙️ Configuration

### Environment Variables
Update these in the test configurations:
- `TEST_ENVIRONMENT`: Target environment (development/staging/production)
- `SLACK_WEBHOOK_URL`: Your Slack webhook for notifications
- Git repository credentials in `git-repo-secret`

### Scheduling
Tests are scheduled to run automatically:
- **Integration tests**: Daily at 6 AM
- **E2E tests**: Daily at 4 AM  
- **Complete test suite**: Daily at 3 AM
- **Performance tests**: Part of the test suite

### Resource Limits
Current resource allocation per test:
- **Memory**: 256Mi request, 512Mi limit
- **CPU**: 100m request, 500m limit

Adjust in the YAML files if needed.

## 🔧 Customization

### Adding New Tests
1. Create a new Test resource YAML
2. Add it to the test suite in `03-kcl-test-suite.yaml`
3. Apply the configuration

### Modifying Test Scripts
1. Update the ConfigMap in `04-environment-config.yaml`
2. Re-apply the configuration
3. Tests will use the updated scripts on next execution

### Environment-Specific Testing
Use the environment configs in `test-environment-config` ConfigMap to customize behavior per environment.

## 📈 What You've Gained

### Before (Nu Shell Scripts)
- ✅ Great local development testing
- ❌ Manual execution only
- ❌ No CI/CD integration
- ❌ No centralized reporting
- ❌ Limited scalability

### After (Testkube)
- ✅ Kubernetes-native testing
- ✅ Automated scheduling & triggers
- ✅ Centralized dashboard & reporting  
- ✅ Integration with monitoring stack
- ✅ Scalable & reliable execution
- ✅ Slack/webhook notifications
- ✅ Historical test data & metrics

## 🛠️ Troubleshooting

### Common Issues

**Test not running?**
```bash
# Check test status
kubectl get tests -n testkube
kubectl describe test kcl-integration-tests -n testkube
```

**Can't access Git repository?**
```bash
# Update git credentials
kubectl create secret generic git-repo-secret \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=token=YOUR_TOKEN \
  -n testkube
```

**KCL installation failing?**
```bash
# Check container logs
kubectl logs -n testkube -l job-name=EXECUTION_ID
```

### Useful Commands
```bash
# Delete all test executions (cleanup)
kubectl testkube delete executions -n testkube

# Restart a failed test
kubectl testkube run test TEST_NAME -n testkube

# Check Testkube API status
kubectl get pods -n testkube -l app.kubernetes.io/name=testkube-api-server
```

## 🎯 Next Steps

1. **Monitor for a week**: Let the tests run automatically and monitor results
2. **Add more applications**: Extend to test your other applications
3. **Integrate with CI/CD**: Trigger tests on deployments
4. **Set up alerting**: Configure Slack/email notifications
5. **Performance optimization**: Tune resource requests based on actual usage

## 📚 Additional Resources

- [Testkube Documentation](https://docs.testkube.io/)
- [KCL Language Documentation](https://kcl-lang.io/)
- [Crossplane Functions Guide](https://docs.crossplane.io/latest/concepts/composition-functions/)

## 🏆 Success Metrics

Track these metrics to measure success:
- **Test execution frequency**: Should run automatically daily
- **Success rate**: Target >95% pass rate
- **Issue detection**: Catch problems before production
- **Time savings**: Reduced manual testing effort
- **Team confidence**: Faster, safer deployments

---

**🎉 Congratulations!** Your KCL Crossplane function testing is now production-ready with Testkube. You've successfully transformed local Nu shell scripts into a scalable, automated, Kubernetes-native testing pipeline.
