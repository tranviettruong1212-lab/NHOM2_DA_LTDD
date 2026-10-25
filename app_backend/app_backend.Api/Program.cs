
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using app_backend.Api.Data;
using app_backend.Api.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Firebase Project ID trong appsettings.json
var firebaseProjectId = builder.Configuration["Firebase:ProjectId"]
    ?? throw new InvalidOperationException(
        "Chưa cấu hình Firebase:ProjectId trong appsettings.json.");
var connectionString = builder.Configuration.GetConnectionString("MoneyMate")
    ?? throw new InvalidOperationException(
        "Chưa cấu hình ConnectionStrings:MoneyMate.");

builder.Services.AddControllersWithViews();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Xác thực Firebase ID Token
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority =
            $"https://securetoken.google.com/{firebaseProjectId}";

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer =
                $"https://securetoken.google.com/{firebaseProjectId}",

            ValidateAudience = true,
            ValidAudience = firebaseProjectId,

            ValidateLifetime = true
        };
    });

builder.Services.AddAuthorization();

// CORS cho Flutter Web
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterFrontend", policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
                allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase)
                || (Uri.TryCreate(origin, UriKind.Absolute, out var uri)
                    && uri.IsLoopback
                    && (uri.Scheme == Uri.UriSchemeHttp
                        || uri.Scheme == Uri.UriSchemeHttps)))
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddDbContext<FinanceManagerDbContext>(options =>
    options.UseSqlServer(connectionString));
    
    builder.Services.AddScoped<CurrentUserService>();
    builder.Services.AddScoped<HouseholdAuthorizationService>();
    builder.Services.AddScoped<TransactionService>();
    builder.Services.AddScoped<ApprovalService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

// CORS phải nằm sau UseRouting và trước xác thực/ủy quyền
app.UseCors("FlutterFrontend");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
