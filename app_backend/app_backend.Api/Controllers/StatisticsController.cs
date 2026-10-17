using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Controllers;

[Route("api/statistics")]
[Authorize]
public sealed class StatisticsController(TransactionService transactions, CurrentUserService currentUserService) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? year, [FromQuery] int? month, [FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        if (month.HasValue && (month < 1 || month > 12)) return BadRequest(new { error = "invalid_month" });
        if (year.HasValue && (year < 2000 || year > 2200)) return BadRequest(new { error = "invalid_year" });
        if (month.HasValue && !year.HasValue) return BadRequest(new { error = "year_required_with_month" });
        if (year.HasValue) { from = month.HasValue ? new DateTime(year.Value, month.Value, 1) : new DateTime(year.Value, 1, 1); to = month.HasValue ? from.Value.AddMonths(1) : from.Value.AddYears(1); }
        if (from.HasValue && to.HasValue && from >= to) return BadRequest(new { error = "invalid_date_range" });
        var q = transactions.VisibleQuery(user, forSummary: true).Where(t => t.Status == TransactionStatus.Approved);
        if (from.HasValue) q = q.Where(t => t.TransactionDate >= from.Value);
        if (to.HasValue) q = q.Where(t => t.TransactionDate < to.Value);
        var income = await q.Where(t => t.Type == TransactionType.Income).SumAsync(t => (decimal?)t.Amount, ct) ?? 0m;
        var expense = await q.Where(t => t.Type == TransactionType.Expense).SumAsync(t => (decimal?)t.Amount, ct) ?? 0m;
        var byCategory = await q.Where(t => t.Type == TransactionType.Expense).GroupBy(t => new { t.CategoryId, Name = t.Category == null ? "Chưa phân loại" : t.Category.Name }).Select(g => new { g.Key.CategoryId, CategoryName = g.Key.Name, Amount = g.Sum(x => x.Amount) }).OrderByDescending(x => x.Amount).ToListAsync(ct);
        return Ok(new { From = from, To = to, Income = income, Expense = expense, Net = income - expense, ExpenseByCategory = byCategory });
    }
}
