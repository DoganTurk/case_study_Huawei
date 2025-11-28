# scripts/quickstart.ps1

Write-Host "Starting Advanced MLOps Infrastructure Setup..." -ForegroundColor Cyan

# --- STEP 1: INFRASTRUCTURE ---
Write-Host "Step 1: Provisioning Kubernetes Cluster (Kind)..." -ForegroundColor Yellow
if (kind get clusters | Select-String "mlops-cluster") {
    Write-Host "   Cluster already exists. Skipping." -ForegroundColor Green
} else {
    kind create cluster --config infrastructure/kind-config.yaml --name mlops-cluster
}

# --- STEP 2: INGRESS ---
Write-Host "Step 2: Installing Ingress Controller..." -ForegroundColor Yellow
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
# Wait for ingress controller to be created
Start-Sleep -Seconds 15

# --- STEP 3: METRICS SERVER (Base Requirement) ---
Write-Host "Step 3: Installing Metrics Server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Patch for Kind
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# --- STEP 4: MODEL BUILD ---
Write-Host "Step 4: Building & Loading Model Image..." -ForegroundColor Yellow
docker build -t sentiment-model:v1 ./model-service
kind load docker-image sentiment-model:v1 --name mlops-cluster

# --- STEP 5: OBSERVABILITY STACK ---
Write-Host "Step 5: Installing Prometheus & Grafana..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# Install Prometheus Stack (named 'monitor')
helm upgrade --install monitor prometheus-community/kube-prometheus-stack --wait

# --- STEP 6: PROMETHEUS ADAPTER (The MLOps Special) ---
Write-Host "Step 6: Installing Prometheus Adapter for Custom Scaling..." -ForegroundColor Yellow

# Dynamically create the config with the CORRECT service URL we found
Set-Content -Path "adapter-values.yaml" -Value @"
prometheus:
  url: "http://monitor-kube-prometheus-st-prometheus.default.svc"
  port: 9090
rules:
  default: false
  custom:
    - seriesQuery: '{__name__=~"^prediction_count_total.*",namespace!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
          pod: {resource: "pod"}
          service: {resource: "service"}
      name:
        matches: "^prediction_count_total"
        as: "requests_per_second"
      metricsQuery: "sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)"
"@

helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter -f adapter-values.yaml --wait

# --- STEP 7: DEPLOY APP & CUSTOM HPA ---
Write-Host "Step 7: Deploying Model & ServiceMonitors..." -ForegroundColor Yellow

# Apply standard manifests first (Deployment, Service, Ingress)
kubectl apply -f deploy/01-deployment.yaml
kubectl apply -f deploy/02-service.yaml
kubectl apply -f deploy/03-ingress.yaml
kubectl apply -f deploy/06-servicemonitor.yaml

# Create and Apply the Custom HPA (Overwriting any CPU HPA)
Set-Content -Path "deploy/04-hpa-custom.yaml" -Value @"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sentiment-hpa-custom
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sentiment-model
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: 10
"@
kubectl apply -f deploy/04-hpa-custom.yaml

# --- FINAL OUTPUT ---
# --- FINAL OUTPUT ---
Write-Host "`nEnvironment Ready!" -ForegroundColor Green
Write-Host "---------------------------------------------------"
$secret = kubectl get secret --namespace default monitor-grafana -o jsonpath="{.data.admin-password}"
$pass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secret))

# Using -f format operator avoids syntax errors with special characters
Write-Host ("Grafana:     http://localhost:3000")
Write-Host ("   User:        admin")
Write-Host ("   Password:    {0}" -f $pass)
Write-Host ("   Connect:     kubectl port-forward svc/monitor-grafana 3000:80")

Write-Host "Model API:   http://localhost:8000/predict"
Write-Host "   Connect:     kubectl port-forward svc/sentiment-service 8000:80"
Write-Host "Autoscaler:  kubectl get hpa -w"