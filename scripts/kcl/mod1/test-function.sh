#!/bin/bash

# Test the KCL function with proper parameters as Crossplane would provide them

echo "Testing KCL function with small size..."
kcl run . -D params='{"oxr": {"metadata": {"name": "small-db", "namespace": "test"}, "spec": {"size": "small"}}, "ocds": {}}'

echo -e "\n\nTesting KCL function with medium size..."
kcl run . -D params='{"oxr": {"metadata": {"name": "medium-db", "namespace": "production"}, "spec": {"size": "medium"}}, "ocds": {}}'

echo -e "\n\nTesting KCL function with large size..."
kcl run . -D params='{"oxr": {"metadata": {"name": "large-db", "namespace": "production"}, "spec": {"size": "large"}}, "ocds": {}}'

echo -e "\n\nTesting with existing composed resources (ocds)..."
kcl run . -D params='{"oxr": {"metadata": {"name": "existing-db", "namespace": "default"}, "spec": {"size": "medium"}}, "ocds": {"cluster": {"Resource": {"status": {"atProvider": {"serviceHost": "existing-cluster.local"}}}}}}'
