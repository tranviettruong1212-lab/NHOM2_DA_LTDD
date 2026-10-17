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
    public async Task<IActionResult> GetExpenseCategories(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        // Seed common expense categories only when the expense category table is empty.
        if (!await db.Categories.AnyAsync(c => c.IsActive && c.Type == TransactionType.Expense, ct))
        {
            var names = new[] { "Ăn uống", "Di chuyển", "Học tập", "Mua sắm", "Giải trí", "Sức khỏe", "Hóa đơn", "Khác" };
            foreach (var name in names)
                db.Categories.Add(new Category { Name = name, Type = TransactionType.Expense, IsSystem = true, IsActive = true });
            await db.SaveChangesAsync(ct);
        }

        var categories = await db.Categories.AsNoTracking()
            .Where(c => c.IsActive && c.Type == TransactionType.Expense)
            .OrderBy(c => c.Name)
            .Select(c => new { c.Id, c.Name, Type = (int)c.Type })
            .ToListAsync(ct);
        return Ok(categories);
    }
}
