# scripts/cleanup.ps1

Write-Host "Tearing down MLOps Environment..." -ForegroundColor Red

# 1. Delete the Cluster
kind delete cluster --name mlops-cluster

Write-Host "Cleaned up successfully." -ForegroundColor Green