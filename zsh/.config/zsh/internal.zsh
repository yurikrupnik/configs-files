internal() {
  kind create cluster
  sleep 20
  istioctl install --set profile=demo -y
#  ds=${gcloud auth print-identity-token}
#  dsa=${gcloud auth print-access-token}
#  echo $dsa
#  echo $ds
}