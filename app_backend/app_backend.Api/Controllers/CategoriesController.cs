// Copy this file into the backend Controllers folder.
// If your current backend namespace differs, change the three app_backend.Api namespaces below.
using app_backend.Api.Data;
using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Controllers;

[ApiController]
[Route("api/categories")]
[Authorize]
public sealed class CategoriesController(FinanceManagerDbContext db, CurrentUserService currentUserService) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetCategories([FromQuery] int type = 0, CancellationToken ct = default)
    {
        if (type != (int)TransactionType.Expense && type != (int)TransactionType.Income)
            return BadRequest(new { error = "invalid_category_type" });

        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        var categoryType = (TransactionType)type;
        if (!await db.Categories.AnyAsync(c => c.IsActive && c.Type == categoryType, ct))
        {
            var names = categoryType == TransactionType.Expense
                ? new[] { "Ăn uống", "Di chuyển", "Học tập", "Mua sắm", "Giải trí", "Sức khỏe", "Hóa đơn", "Khác" }
                : new[] { "Lương", "Thưởng", "Khác" };
            foreach (var name in names)
                db.Categories.Add(new Category { Name = name, Type = categoryType, IsSystem = true, IsActive = true });
            await db.SaveChangesAsync(ct);
        }

        var categories = await db.Categories.AsNoTracking()
            .Where(c => c.IsActive && c.Type == categoryType)
            .OrderBy(c => c.Name)
            .Select(c => new { c.Id, c.Name, Type = (int)c.Type })
            .ToListAsync(ct);
        return Ok(categories);
    }
}
