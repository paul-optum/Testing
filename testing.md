You are a senior enterprise architect and principal .NET engineer.

Generate a complete .NET 9 solution that serves TWO purposes:

1. A working Demo API host for WellHive Phase 1
2. A reusable SDK/Foundation for building future WellHive APIs

This is NOT a full production system. It is a CLEAN, EXTENSIBLE FOUNDATION that other teams will build on.

---------------------------------------
## 🧱 SOLUTION STRUCTURE (CRITICAL)
---------------------------------------

Create a multi-project solution:

/src
  WellHive.Api            (Demo Host)
  WellHive.Core           (Contracts, Models, Interfaces)
  WellHive.Providers      (Data providers: mock + future-ready)
  WellHive.Infrastructure (Cross-cutting concerns)

/tests
  WellHive.Tests

---------------------------------------

## 🧠 DESIGN PRINCIPLES

- Clean architecture
- Strict separation of concerns
- Dependency Injection everywhere
- Async-first
- Designed for EXTENSION, not completion

---------------------------------------

## 🌐 API (DEMO HOST ONLY)

Base route:
/api/v1

Endpoints:

GET /organizations
GET /organizations/{id}

GET /provider-services?organizationId={id}
GET /provider-services/{id}

---------------------------------------

## 📦 CONTRACTS (IN WellHive.Core)

Define:

- Organization model
- ProviderService model
- PagedResult<T>
- ErrorResponse
- QueryParams

These MUST be reusable across future services.

---------------------------------------

## 🔌 PROVIDER MODEL (KEY SDK FEATURE)

In Core:

Define:
IReferenceDataProvider

In Providers:

Implement:
MockReferenceDataProvider

Design so future providers can be added:
- PostgresReferenceDataProvider
- MedNetApiProvider

NO code should depend directly on Mock.

---------------------------------------

## 🔄 PAGINATION ENGINE (SDK LEVEL)

Create reusable pagination service:

IPaginationService

Requirements:
- Base64 token encoding
- Stateless
- Reusable across ANY endpoint
- Not tied to specific models

---------------------------------------

## 🔐 AUTH (SDK-AWARE)

Implement JWT middleware, BUT:

- Configurable strict vs relaxed mode
- Reusable middleware component
- Not tied to demo host

---------------------------------------

## 📊 MOCK DATA

- 200 organizations
- 400+ provider services
- Deterministic
- Linked relationships

---------------------------------------

## ⚙️ CONFIGURATION

Environment-driven:

- PAGINATION_DEFAULT_PAGE_SIZE (default 10)
- AUTH_RELAXED
- LOG_LEVEL

---------------------------------------

## 🧪 TESTING

Use xUnit

Test:
- Pagination logic (Core layer)
- Provider filtering (Providers layer)
- API endpoints (Api project)

Focus on testability via DI

---------------------------------------

## 🧱 INFRASTRUCTURE

In Infrastructure project:

- Logging setup
- Middleware (error handling, correlation ID)
- Token handling utilities

---------------------------------------

## 🐳 DOCKER

Provide Dockerfile for API project

---------------------------------------

## ☸️ KUBERNETES + FLUX (BASELINE ONLY)

Provide:

deploy/base:
- deployment.yaml
- service.yaml
- kustomization.yaml

deploy/overlays/dev:
- kustomization.yaml

- Include env vars for:
  - DB connection string
  - pagination config
  - auth config
- Include readiness and liveness probes
This is ONLY a baseline, not full infra provisioning

---------------------------------------

## 📘 README (VERY IMPORTANT)

Explain clearly:

- This is a Foundation/SDK
- How to extend providers
- How to add new endpoints
- How to replace mock data
- Future path:
  - Postgres
  - Redis pagination
  - Strict auth

---------------------------------------

## 🚀 OUTPUT REQUIREMENTS

- Complete solution
- All files included
- Builds with:
  dotnet build
- Runs immediately

NO placeholders. NO TODOs.

---------------------------------------

## 🔄 CI/CD PIPELINE

Provide a GitHub Actions workflow that:

- Builds the .NET 9 solution
- Runs tests
- Builds Docker image
- Tags image
- Pushes to container registry (use placeholder)
- Outputs image for deployment

Keep it simple and clear.

---------------------------------------

## 🗄️ DATABASE FOUNDATION (POSTGRES)

Implement minimal Postgres support:

- Add configuration for connection string
- Include DbContext or connection test service
- Add a health check that verifies DB connectivity

DO NOT implement full schema or persistence logic.

Goal: Prove the service can connect to Postgres.

---------------------------------------

## 📊 MONITORING & OBSERVABILITY

Implement:

- Structured logging
- Health endpoint at /health
- Readiness check endpoint
- Include basic telemetry logging for requests

Optional:
- OpenTelemetry placeholder setup

---------------------------------------


END
