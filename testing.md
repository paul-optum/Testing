Write-Host "Writing Infrastructure csproj with FrameworkReference..."
Set-Content -Path "src/WellHive.Infrastructure/WellHive.Infrastructure.csproj" -Value @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Configuration.Abstractions" Version="9.0.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\WellHive.Core\WellHive.Core.csproj" />
  </ItemGroup>
</Project>
'@

Write-Host "Writing DevOps & Configuration Files..."
Set-Content -Path "azure-pipelines.yml" -Value @'
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  imageName: 'your-registry.com/wellhive-api'

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
    # containerRegistry: 'YourDockerServiceConnectionName'
'@

Set-Content -Path "Dockerfile" -Value @'
FROM mcr.microsoft.com/dotnet/sdk:9.0-preview AS build
WORKDIR /source

COPY *.sln .
COPY src/WellHive.Api/*.csproj src/WellHive.Api/
COPY src/WellHive.Core/*.csproj src/WellHive.Core/
COPY src/WellHive.Infrastructure/*.csproj src/WellHive.Infrastructure/
COPY src/WellHive.Providers/*.csproj src/WellHive.Providers/
COPY tests/WellHive.Tests/*.csproj tests/WellHive.Tests/
RUN dotnet restore

COPY src/ src/
COPY tests/ tests/
WORKDIR /source/src/WellHive.Api
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0-preview AS runtime
WORKDIR /app
COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "WellHive.Api.dll"]
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
    spec:
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

Set-Content -Path "deploy/base/service.yaml" -Value @'
apiVersion: v1
kind: Service
metadata:
  name: wellhive-api-service
spec:
  selector:
    app: wellhive-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
'@

Set-Content -Path "deploy/base/kustomization.yaml" -Value @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
commonLabels:
  app: wellhive-api
'@

Set-Content -Path "deploy/overlays/dev/kustomization.yaml" -Value @'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namePrefix: dev-
patches:
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: wellhive-api
      spec:
        replicas: 1
        template:
          spec:
            containers:
            - name: api
              env:
              - name: ConnectionStrings__DefaultConnection
                value: "Host=localhost;Database=dev_db;Username=dev;Password=dev"
              - name: LOG_LEVEL
                value: "Debug"
'@

Write-Host "Writing Core Models & Interfaces..."
Set-Content -Path "src/WellHive.Core/Models/Organization.cs" -Value @'
namespace WellHive.Core.Models;
public class Organization
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
'@

Set-Content -Path "src/WellHive.Core/Models/ProviderService.cs" -Value @'
namespace WellHive.Core.Models;
public class ProviderService
{
    public Guid Id { get; set; }
    public Guid OrganizationId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Specialty { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
'@

Set-Content -Path "src/WellHive.Core/Models/PagedResult.cs" -Value @'
namespace WellHive.Core.Models;
public class PagedResult<T>
{
    public IEnumerable<T> Data { get; set; } = new List<T>();
    public int TotalCount { get; set; }
    public string? NextPageToken { get; set; }
}
'@

Set-Content -Path "src/WellHive.Core/Models/ErrorResponse.cs" -Value @'
namespace WellHive.Core.Models;
public class ErrorResponse
{
    public string Message { get; set; } = string.Empty;
    public string? Code { get; set; }
    public string? Details { get; set; }
}
'@

Set-Content -Path "src/WellHive.Core/Models/QueryParams.cs" -Value @'
namespace WellHive.Core.Models;
public class QueryParams
{
    public int PageSize { get; set; } = 10;
    public string? PageToken { get; set; }
}
'@

Set-Content -Path "src/WellHive.Core/Interfaces/IPaginationService.cs" -Value @'
using WellHive.Core.Models;
namespace WellHive.Core.Interfaces;
public interface IPaginationService
{
    string EncodePageToken(int offset);
    int DecodePageToken(string token);
    PagedResult<T> Paginate<T>(IEnumerable<T> source, QueryParams queryParams);
}
'@

Set-Content -Path "src/WellHive.Core/Interfaces/IReferenceDataProvider.cs" -Value @'
using WellHive.Core.Models;
namespace WellHive.Core.Interfaces;
public interface IReferenceDataProvider
{
    Task<PagedResult<Organization>> GetOrganizationsAsync(QueryParams queryParams, CancellationToken cancellationToken = default);
    Task<Organization?> GetOrganizationByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<PagedResult<ProviderService>> GetProviderServicesAsync(Guid? organizationId, QueryParams queryParams, CancellationToken cancellationToken = default);
    Task<ProviderService?> GetProviderServiceByIdAsync(Guid id, CancellationToken cancellationToken = default);
}
'@

Write-Host "Writing Infrastructure Services & Middleware..."
Set-Content -Path "src/WellHive.Infrastructure/Services/PaginationService.cs" -Value @'
using System.Text;
using WellHive.Core.Interfaces;
using WellHive.Core.Models;
namespace WellHive.Infrastructure.Services;
public class PaginationService : IPaginationService
{
    public string EncodePageToken(int offset)
    {
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(offset.ToString()));
    }
    public int DecodePageToken(string token)
    {
        if (string.IsNullOrWhiteSpace(token)) return 0;
        try {
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(token));
            return int.TryParse(decoded, out var offset) ? offset : 0;
        } catch { return 0; }
    }
    public PagedResult<T> Paginate<T>(IEnumerable<T> source, QueryParams queryParams)
    {
        var offset = DecodePageToken(queryParams.PageToken ?? string.Empty);
        var totalCount = source.Count();
        var pageSize = queryParams.PageSize > 0 ? queryParams.PageSize : 10;
        
        var data = source.Skip(offset).Take(pageSize).ToList();
        var nextOffset = offset + pageSize;
        
        return new PagedResult<T> {
            Data = data,
            TotalCount = totalCount,
            NextPageToken = nextOffset < totalCount ? EncodePageToken(nextOffset) : null
        };
    }
}
'@

Set-Content -Path "src/WellHive.Infrastructure/Middleware/ErrorHandlingMiddleware.cs" -Value @'
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using WellHive.Core.Models;
namespace WellHive.Infrastructure.Middleware;
public class ErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ErrorHandlingMiddleware> _logger;
    public ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
    {
        _next = next; _logger = logger;
    }
    public async Task InvokeAsync(HttpContext context)
    {
        try { await _next(context); }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception occurred.");
            context.Response.ContentType = "application/json";
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            var response = new ErrorResponse { Message = "An internal server error occurred.", Code = "500" };
            await context.Response.WriteAsync(JsonSerializer.Serialize(response));
        }
    }
}
'@

Set-Content -Path "src/WellHive.Infrastructure/Middleware/JwtMiddleware.cs" -Value @'
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
namespace WellHive.Infrastructure.Middleware;
public class JwtMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConfiguration _config;
    public JwtMiddleware(RequestDelegate next, IConfiguration config)
    {
        _next = next; _config = config;
    }
    public async Task InvokeAsync(HttpContext context)
    {
        var isRelaxed = _config.GetValue<bool>("AUTH_RELAXED");
        if (!isRelaxed)
        {
            var token = context.Request.Headers["Authorization"].FirstOrDefault()?.Split(" ").Last();
            if (token == null)
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                return;
            }
        }
        await _next(context);
    }
}
'@

Write-Host "Writing Providers Data Logic..."
Set-Content -Path "src/WellHive.Providers/WellHiveDbContext.cs" -Value @'
using Microsoft.EntityFrameworkCore;
using WellHive.Core.Models;
namespace WellHive.Providers;
public class WellHiveDbContext : DbContext
{
    public WellHiveDbContext(DbContextOptions<WellHiveDbContext> options) : base(options) { }
    // DbSet<Organization> Organizations { get; set; }
    // DbSet<ProviderService> ProviderServices { get; set; }
}
'@

Set-Content -Path "src/WellHive.Providers/MockReferenceDataProvider.cs" -Value @'
using Bogus;
using WellHive.Core.Interfaces;
using WellHive.Core.Models;
namespace WellHive.Providers;
public class MockReferenceDataProvider : IReferenceDataProvider
{
    private readonly List<Organization> _organizations;
    private readonly List<ProviderService> _providerServices;
    private readonly IPaginationService _paginationService;
    public MockReferenceDataProvider(IPaginationService paginationService)
    {
        _paginationService = paginationService;
        Randomizer.Seed = new Random(42);
        
        var orgFaker = new Faker<Organization>()
            .RuleFor(o => o.Id, f => f.Random.Guid())
            .RuleFor(o => o.Name, f => f.Company.CompanyName())
            .RuleFor(o => o.Description, f => f.Company.CatchPhrase())
            .RuleFor(o => o.CreatedAt, f => f.Date.Past(2))
            .RuleFor(o => o.UpdatedAt, f => f.Date.Recent());
        _organizations = orgFaker.Generate(200);
        var orgIds = _organizations.Select(o => o.Id).ToList();

        var serviceFaker = new Faker<ProviderService>()
            .RuleFor(s => s.Id, f => f.Random.Guid())
            .RuleFor(s => s.OrganizationId, f => f.PickRandom(orgIds))
            .RuleFor(s => s.Name, f => f.Commerce.ProductName())
            .RuleFor(s => s.Specialty, f => f.Name.JobTitle())
            .RuleFor(s => s.IsActive, f => f.Random.Bool(0.9f))
            .RuleFor(s => s.CreatedAt, f => f.Date.Past(1))
            .RuleFor(s => s.UpdatedAt, f => f.Date.Recent());
        _providerServices = serviceFaker.Generate(450);
    }
    public Task<PagedResult<Organization>> GetOrganizationsAsync(QueryParams queryParams, CancellationToken ct = default) =>
        Task.FromResult(_paginationService.Paginate(_organizations, queryParams));

    public Task<Organization?> GetOrganizationByIdAsync(Guid id, CancellationToken ct = default) =>
        Task.FromResult(_organizations.FirstOrDefault(o => o.Id == id));

    public Task<PagedResult<ProviderService>> GetProviderServicesAsync(Guid? orgId, QueryParams queryParams, CancellationToken ct = default)
    {
        var query = _providerServices.AsEnumerable();
        if (orgId.HasValue) query = query.Where(s => s.OrganizationId == orgId.Value);
        return Task.FromResult(_paginationService.Paginate(query, queryParams));
    }

    public Task<ProviderService?> GetProviderServiceByIdAsync(Guid id, CancellationToken ct = default) =>
        Task.FromResult(_providerServices.FirstOrDefault(s => s.Id == id));
}
'@

Write-Host "Writing API Controllers & Program.cs..."
Set-Content -Path "src/WellHive.Api/Controllers/OrganizationsController.cs" -Value @'
using Microsoft.AspNetCore.Mvc;
using WellHive.Core.Interfaces;
using WellHive.Core.Models;
namespace WellHive.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class OrganizationsController : ControllerBase
{
    private readonly IReferenceDataProvider _dataProvider;
    public OrganizationsController(IReferenceDataProvider dataProvider) { _dataProvider = dataProvider; }

    [HttpGet]
    public async Task<ActionResult<PagedResult<Organization>>> GetOrganizations([FromQuery] QueryParams queryParams) =>
        Ok(await _dataProvider.GetOrganizationsAsync(queryParams));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<Organization>> GetOrganizationById(Guid id)
    {
        var result = await _dataProvider.GetOrganizationByIdAsync(id);
        if (result == null) return NotFound(new ErrorResponse { Message = $"Organization {id} not found", Code = "404" });
        return Ok(result);
    }
}
'@

Set-Content -Path "src/WellHive.Api/Controllers/ProviderServicesController.cs" -Value @'
using Microsoft.AspNetCore.Mvc;
using WellHive.Core.Interfaces;
using WellHive.Core.Models;
namespace WellHive.Api.Controllers;

[ApiController]
[Route("api/v1/provider-services")]
public class ProviderServicesController : ControllerBase
{
    private readonly IReferenceDataProvider _dataProvider;
    public ProviderServicesController(IReferenceDataProvider dataProvider) { _dataProvider = dataProvider; }

    [HttpGet]
    public async Task<ActionResult<PagedResult<ProviderService>>> GetProviderServices([FromQuery] Guid? organizationId, [FromQuery] QueryParams queryParams) =>
        Ok(await _dataProvider.GetProviderServicesAsync(organizationId, queryParams));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ProviderService>> GetProviderServiceById(Guid id)
    {
        var result = await _dataProvider.GetProviderServiceByIdAsync(id);
        if (result == null) return NotFound(new ErrorResponse { Message = $"Provider service {id} not found", Code = "404" });
        return Ok(result);
    }
}
'@

Set-Content -Path "src/WellHive.Api/Program.cs" -Value @'
using Microsoft.EntityFrameworkCore;
using WellHive.Core.Interfaces;
using WellHive.Infrastructure.Middleware;
using WellHive.Infrastructure.Services;
using WellHive.Providers;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSingleton<IPaginationService, PaginationService>();
builder.Services.AddSingleton<IReferenceDataProvider, MockReferenceDataProvider>();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (!string.IsNullOrEmpty(connectionString))
{
    builder.Services.AddDbContext<WellHiveDbContext>(options => options.UseNpgsql(connectionString));
    builder.Services.AddHealthChecks().AddDbContextCheck<WellHiveDbContext>("postgres");
}
else
{
    builder.Services.AddHealthChecks();
}

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.UseMiddleware<ErrorHandlingMiddleware>();
app.UseMiddleware<JwtMiddleware>();
app.UseHttpsRedirection();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
'@

Write-Host "Setup complete!"
