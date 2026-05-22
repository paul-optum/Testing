$ErrorActionPreference = 'Stop'

Write-Host "Creating docker-compose.yml..."
Set-Content -Path "docker-compose.yml" -Value @'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: dev_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - ConnectionStrings__DefaultConnection=Host=db;Database=dev_db;Username=dev;Password=dev
      - PAGINATION_DEFAULT_PAGE_SIZE=10
      - AUTH_RELAXED=true
    depends_on:
      - db

volumes:
  postgres_data:
'@

Write-Host "Updating azure-pipelines.yml with Postgres service..."
Set-Content -Path "azure-pipelines.yml" -Value @'
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  imageName: 'your-registry.com/wellhive-api'

# Ensure Postgres is available for integration tests
services:
  postgres:
    image: postgres:15-alpine
    env:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: dev_db
    ports:
      - 5432:5432
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5

steps:
- task: UseDotNet@2
  displayName: 'Use .NET 9 SDK'
  inputs:
    packageType: 'sdk'
    version: '9.0.x'
    includePreviewVersions: true

- task: DotNetCoreCLI@2
  displayName: 'Restore solution'
  inputs:
    command: 'restore'
    projects: 'WellHive.sln'

- task: DotNetCoreCLI@2
  displayName: 'Build solution'
  inputs:
    command: 'build'
    projects: 'WellHive.sln'
    arguments: '--no-restore --configuration $(buildConfiguration)'

- task: DotNetCoreCLI@2
  displayName: 'Test solution'
  inputs:
    command: 'test'
    projects: 'WellHive.sln'
    arguments: '--no-build --configuration $(buildConfiguration) --verbosity normal'

- task: Docker@2
  displayName: 'Build Docker image'
  inputs:
    command: 'build'
    repository: '$(imageName)'
    dockerfile: 'Dockerfile'
    tags: '$(Build.BuildId)'

- task: Docker@2
  displayName: 'Push Docker image'
  inputs:
    command: 'push'
    repository: '$(imageName)'
    tags: '$(Build.BuildId)'
'@

Write-Host "Updating Kubernetes Base Files (Adding SA and ElasticSearch annotations)..."
Set-Content -Path "deploy/base/serviceaccount.yaml" -Value @'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wellhive-api-sa
'@

Set-Content -Path "deploy/base/deployment.yaml" -Value @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wellhive-api
  labels:
    app: wellhive-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wellhive-api
  template:
    metadata:
      labels:
        app: wellhive-api
      # ElasticSearch Logging Annotations
      annotations:
        co.elastic.logs/enabled: "true"
        co.elastic.logs/json.keys_under_root: "true"
        co.elastic.logs/json.overwrite_keys: "true"
    spec:
      serviceAccountName: wellhive-api-sa
      containers:
      - name: api
        image: wellhive-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: ConnectionStrings__DefaultConnection
          value: ""
        - name: PAGINATION_DEFAULT_PAGE_SIZE
          value: "10"
        - name: AUTH_RELAXED
          value: "true"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
'@

Set-Content -Path "deploy/base/kustomization.yaml" -Value @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - serviceaccount.yaml
  - deployment.yaml
  - service.yaml
commonLabels:
  app: wellhive-api
'@

Write-Host "Updating Dev Overlay..."
Set-Content -Path "deploy/overlays/dev/kustomization.yaml" -Value @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namePrefix: dev-

patches:
  # 1. Update Service Account configuration for Dev
  - target:
      kind: ServiceAccount
      name: wellhive-api-sa
    patch: |-
      - op: replace
        path: /metadata/name
        value: dev-service-account-name
  # 2. Update Deployment configuration (DB, Env, SA reference)
  - target:
      kind: Deployment
      name: wellhive-api
    patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: wellhive-api
      spec:
        replicas: 1
        template:
          spec:
            serviceAccountName: dev-service-account-name
            containers:
            - name: api
              env:
              - name: ConnectionStrings__DefaultConnection
                value: "Host=dev-db-server;Database=dev_db;Username=dev;Password=dev"
              - name: LOG_LEVEL
                value: "Debug"
  # 3. Update Service to expose a specific IP for Dev
  - target:
      kind: Service
      name: wellhive-api-service
    patch: |-
      apiVersion: v1
      kind: Service
      metadata:
        name: wellhive-api-service
      spec:
        type: LoadBalancer
        loadBalancerIP: 10.0.10.50
'@

Write-Host "Creating Stage Overlay..."
New-Item -ItemType Directory -Path "deploy/overlays/stage" -Force | Out-Null
Set-Content -Path "deploy/overlays/stage/kustomization.yaml" -Value @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namePrefix: stage-

patches:
  # 1. Update Service Account configuration for Stage
  - target:
      kind: ServiceAccount
      name: wellhive-api-sa
    patch: |-
      - op: replace
        path: /metadata/name
        value: stage-service-account-name
  # 2. Update Deployment configuration (DB, Env, SA reference)
  - target:
      kind: Deployment
      name: wellhive-api
    patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: wellhive-api
      spec:
        replicas: 2
        template:
          spec:
            serviceAccountName: stage-service-account-name
            containers:
            - name: api
              env:
              - name: ConnectionStrings__DefaultConnection
                value: "Host=stage-db-server;Database=stage_db;Username=stage;Password=stage"
              - name: LOG_LEVEL
                value: "Information"
  # 3. Update Service to expose a specific IP for Stage
  - target:
      kind: Service
      name: wellhive-api-service
    patch: |-
      apiVersion: v1
      kind: Service
      metadata:
        name: wellhive-api-service
      spec:
        type: LoadBalancer
        loadBalancerIP: 10.0.20.100
'@

Write-Host "Infrastructure Update Complete!"
