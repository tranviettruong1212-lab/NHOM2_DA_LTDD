
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
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterFrontend", policy =>
    {
        policy
            .WithOrigins(
                "http://localhost:54811",
                "http://127.0.0.1:54811",
                "http://localhost:57434",
                "http://127.0.0.1:57434"
            )
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddDbContext<FinanceManagerDbContext>(options =>
        options.UseSqlServer(
            builder.Configuration.GetConnectionString("MoneyMate")));
    
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
