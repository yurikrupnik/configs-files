# Resource-Focused Testing Explained

## 🤔 What Do I Mean by "Resource-Focused Testing"?

Let me break this down with your actual KCL function as an example.

## 📊 Two Levels of Testing Your KCL Function

### **Level 1: Function-Focused Testing (What Testkube Does)**
**Tests the KCL function code itself**

```bash
# Your Nu shell / Testkube approach
kcl run . -D 'params={"oxr": {"metadata": {"name": "test-db"}, "spec": {"size": "medium"}}, "ocds": {}}'

# Output: YAML text that represents Kubernetes resources
oxr:
  metadata:
    name: test-db
  spec:
    size: medium
items:
- apiVersion: postgresql.cnpg.io/v1
  kind: Cluster
  metadata:
    name: test-db
  spec:
    instances: 3
    storage:
      size: '3Gi'
- apiVersion: kubernetes.m.crossplane.io/v1alpha1
  kind: Object
  metadata:
    name: test-db-secret
```

**What this tests:**
✅ KCL syntax is correct  
✅ Function logic works (small=1 instance, medium=3 instances, large=6 instances)  
✅ YAML output is valid  
✅ Naming conventions are followed  
✅ Performance of the function execution  

**What this DOESN'T test:**
❌ Will these resources actually work in Kubernetes?  
❌ Do they integrate properly with other components?  
❌ Are there conflicts with existing resources?  
❌ Do they reach the desired state after creation?  

### **Level 2: Resource-Focused Testing (What Chainsaw Does)**
**Tests the actual Kubernetes resources in a real cluster**

## 🎯 Practical Example: Why Resource-Focused Testing Matters

Let me show you scenarios where your KCL function generates "correct" YAML but the resources fail in practice:

### **Scenario 1: Valid YAML, Invalid Kubernetes Resource**

**Your KCL function output (looks correct):**
```yaml
- apiVersion: postgresql.cnpg.io/v1
  kind: Cluster
  metadata:
    name: test-db
  spec:
    instances: 3
    storage:
      size: '3Gi'
    # Missing required field: postgresql.image
```

**Testkube test:** ✅ PASS (YAML syntax is valid)  
**Chainsaw test:** ❌ FAIL (PostgreSQL operator rejects the resource)

### **Scenario 2: Resource Conflicts**

**Your KCL function output:**
```yaml
- apiVersion: postgresql.cnpg.io/v1
  kind: Cluster
  metadata:
    name: production-db  # This name already exists!
  spec:
    instances: 3
```

**Testkube test:** ✅ PASS (output looks fine)  
**Chainsaw test:** ❌ FAIL (name conflict in cluster)

### **Scenario 3: Dependent Resource Issues**

**Your KCL function generates:**
```yaml
- apiVersion: kubernetes.m.crossplane.io/v1alpha1
  kind: Object
  metadata:
    name: test-db-secret
  spec:
    references:
    - patchesFrom:
        name: "test-db-app"  # This secret doesn't exist yet
```

**Testkube test:** ✅ PASS (YAML is valid)  
**Chainsaw test:** ❌ FAIL (referenced secret doesn't exist)

## 🔍 What Resource-Focused Testing Actually Does

Here's what Chainsaw would test that your current Testkube approach doesn't:

### **1. Resource Creation Success**
```yaml
# Chainsaw test step
- name: verify-cluster-created
  assert:
    resource:
      apiVersion: postgresql.cnpg.io/v1
      kind: Cluster
      metadata:
        name: test-db
      # This checks the resource actually exists in the cluster
```

### **2. Resource State Validation**
```yaml
# Check that the PostgreSQL cluster reaches ready state
- name: verify-cluster-ready
  assert:
    resource:
      apiVersion: postgresql.cnpg.io/v1
      kind: Cluster
      metadata:
        name: test-db
      status:
        conditions:
        - type: Ready
          status: "True"
```

### **3. Integration Testing**
```yaml
# Check that secrets are actually created and populated
- name: verify-secret-populated
  assert:
    resource:
      apiVersion: v1
      kind: Secret
      metadata:
        name: test-db-secret
      data:
        # Verify the secret has the expected data
```

### **4. Cross-Resource Dependencies**
```yaml
# Verify the generated Object resource can actually reference the cluster
- name: verify-object-references
  assert:
    resource:
      apiVersion: kubernetes.m.crossplane.io/v1alpha1
      kind: Object
      metadata:
        name: test-db-secret
      status:
        conditions:
        - type: Ready
          status: "True"
```

## 📈 The Testing Pyramid for Your KCL Function

```
    🔺 Resource-Focused Testing (Chainsaw)
   /    \ 
  /      \     • Tests in real Kubernetes cluster
 /        \    • Validates resource interactions  
/__________\   • Checks actual operational behavior

🔳 Function-Focused Testing (Testkube)
 • Tests KCL function logic
 • Validates YAML output
 • Performance testing
 • Cross-environment testing
```

## 🚀 When Would You Need Resource-Focused Testing?

### **You DON'T need it yet if:**
- Your KCL function is simple and generates standard resources
- You're confident in your resource definitions
- You're in early development/prototyping phase
- Your main concern is function logic correctness

### **You WOULD need it when:**
- Deploying to production environments
- Your KCL function generates complex resource relationships
- You've had issues with resources failing in certain clusters
- You want to test upgrades/changes to resource schemas
- You need to validate cross-namespace or cross-cluster scenarios

## 💡 Real-World Example: Your PostgreSQL Function

### **Current Testkube Testing (Perfect for now):**
```bash
# Tests function logic
✅ small → 1 instance, 1Gi storage
✅ medium → 3 instances, 3Gi storage  
✅ large → 6 instances, 6Gi storage
✅ Proper naming and annotations
✅ Performance benchmarks
```

### **Future Chainsaw Testing (When you need it):**
```yaml
# Tests actual cluster behavior
✅ PostgreSQL operator accepts the cluster spec
✅ Cluster reaches running state with correct pod count
✅ Storage is actually allocated and accessible
✅ Secrets are created and contain valid connection strings
✅ Network policies allow proper access
✅ Backup/restore functionality works
```

## 🎯 My Recommendation Timeline

### **Phase 1 (Now): Function-Focused Testing with Testkube**
- Deploy the Testkube setup we built
- Test your KCL function logic thoroughly
- Validate output correctness and performance
- Perfect for development and initial production use

### **Phase 2 (Later): Add Resource-Focused Testing with Chainsaw**
- When you start having resource-related issues in production
- When you need to test complex multi-resource scenarios
- When you're doing major infrastructure changes
- When you want comprehensive pre-production validation

## 📋 Practical Next Steps

**For now (recommended):**
1. Use the Testkube setup: `./deploy-testkube.sh`
2. This covers 90% of your testing needs
3. Focus on perfecting your KCL function logic

**Later (when needed):**
1. Install Chainsaw in your cluster
2. Use the `chainsaw-kcl-test.yaml` I created
3. Run end-to-end resource validation
4. This covers the remaining 10% edge cases

## 🔧 Quick Example of Both Together

**Testkube catches function bugs:**
```yaml
# Bug: Wrong instance count logic
if oxr.spec.size == "medium":
    instances = 2  # Should be 3!

# Testkube test: ❌ FAIL - Expected 3 instances, got 2
```

**Chainsaw catches resource bugs:**
```yaml
# Bug: Invalid storage class
storage:
  storageClass: "fast-ssd-typo"  # Doesn't exist in cluster

# Chainsaw test: ❌ FAIL - PVC creation failed, storage class not found
```

## 🏁 Summary

**"Resource-focused testing"** means testing the actual Kubernetes resources in a real cluster environment, not just testing that your KCL function generates valid YAML.

Your current Testkube approach is excellent for testing the KCL function itself. Resource-focused testing with Chainsaw would be an additional layer to test how those resources actually behave in Kubernetes - but you don't need it immediately.

**Start with Testkube, add Chainsaw later when you need deeper cluster integration testing!**
