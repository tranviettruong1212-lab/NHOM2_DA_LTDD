using app_backend.Api.Data;
using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace app_backend.Api.Controllers;

[Route("api/budgets")]
[Authorize]
public sealed class BudgetsController(FinanceManagerDbContext db, CurrentUserService currentUserService, HouseholdAuthorizationService householdAuth) : ApiControllerBase
{
    public sealed record BudgetRequest([Required, MaxLength(150)] string Name, decimal LimitAmount, BudgetPeriod Period, BudgetMode Mode, BudgetPriority Priority, DateTime StartDate, DateTime? EndDate, Guid? CategoryId, Guid? HouseholdId = null);
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var budgets = await db.Budgets.AsNoTracking().Where(b => b.IsActive && (b.CreatedByUserId == user.Id || (b.HouseholdId != null && db.HouseholdMembers.Any(m => m.HouseholdId == b.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active)))).OrderByDescending(b => b.Priority).ThenBy(b => b.Name).ToListAsync(ct);
        var now = DateTime.UtcNow.Date;
        var output = new List<object>();
        foreach (var b in budgets)
        {
            var (start, end) = PeriodBounds(b, now);
            var q = db.Transactions.AsNoTracking().Where(t => !t.IsDeleted && t.Status == TransactionStatus.Approved && t.Type == TransactionType.Expense && t.TransactionDate >= start && t.TransactionDate < end);
            q = b.HouseholdId.HasValue ? q.Where(t => t.HouseholdId == b.HouseholdId) : q.Where(t => t.CreatedByUserId == user.Id && t.HouseholdId == null);
            if (b.CategoryId.HasValue) q = q.Where(t => t.CategoryId == b.CategoryId);
            var spent = await q.SumAsync(t => (decimal?)t.Amount, ct) ?? 0m;
            output.Add(new { b.Id, b.Name, b.LimitAmount, b.Period, b.Mode, b.Priority, b.StartDate, b.EndDate, b.CategoryId, b.HouseholdId, SpentAmount = spent, RemainingAmount = b.LimitAmount - spent, Progress = Math.Min(1m, spent / b.LimitAmount) });
        }
        return Ok(output);
    }
    [HttpPost]
    public async Task<IActionResult> Create(BudgetRequest r, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var error = await ValidateAsync(user, r, ct); if (error is not null) return ServiceError(error);
        var b = new Budget { CreatedByUserId = user.Id, HouseholdId = r.HouseholdId, CategoryId = r.CategoryId, Name = r.Name.Trim(), LimitAmount = r.LimitAmount, Period = r.Period, Mode = r.Mode, Priority = r.Priority, StartDate = r.StartDate.Date, EndDate = r.EndDate?.Date };
        db.Budgets.Add(b); await db.SaveChangesAsync(ct); return Created($"/api/budgets/{b.Id}", b);
    }
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, BudgetRequest r, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var b = await db.Budgets.SingleOrDefaultAsync(x => x.Id == id && x.IsActive, ct); if (b is null) return NotFound();
        if (b.CreatedByUserId != user.Id && (!b.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(b.HouseholdId.Value, user.Id, ct))) return Forbid();
        var error = await ValidateAsync(user, r, ct); if (error is not null) return ServiceError(error);
        b.Name = r.Name.Trim(); b.LimitAmount = r.LimitAmount; b.Period = r.Period; b.Mode = r.Mode; b.Priority = r.Priority; b.StartDate = r.StartDate.Date; b.EndDate = r.EndDate?.Date; b.CategoryId = r.CategoryId; b.HouseholdId = r.HouseholdId;
        await db.SaveChangesAsync(ct); return Ok(b);
    }
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var b = await db.Budgets.SingleOrDefaultAsync(x => x.Id == id && x.IsActive, ct); if (b is null) return NotFound();
        if (b.CreatedByUserId != user.Id && (!b.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(b.HouseholdId.Value, user.Id, ct))) return Forbid();
        b.IsActive = false; await db.SaveChangesAsync(ct); return NoContent();
    }
    private async Task<string?> ValidateAsync(User user, BudgetRequest r, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Trim().Length > 150 || r.LimitAmount <= 0 || !Enum.IsDefined(r.Period) || !Enum.IsDefined(r.Mode) || !Enum.IsDefined(r.Priority) || r.StartDate == default || (r.EndDate.HasValue && r.EndDate.Value.Date < r.StartDate.Date)) return "invalid_budget";
        if (r.HouseholdId.HasValue && await householdAuth.GetActiveMembershipAsync(r.HouseholdId.Value, user.Id, ct) is null) return "household_forbidden";
        if (r.CategoryId.HasValue && !await db.Categories.AnyAsync(c => c.Id == r.CategoryId.Value && c.IsActive && c.Type == TransactionType.Expense, ct)) return "category_not_found";
        return null;
    }
    private static (DateTime Start, DateTime End) PeriodBounds(Budget b, DateTime now)
    {
        DateTime start, end;
        switch (b.Period)
        {
            case BudgetPeriod.Weekly: start = now.AddDays(-(((int)now.DayOfWeek + 6) % 7)); end = start.AddDays(7); break;
            case BudgetPeriod.Yearly: start = new DateTime(now.Year, 1, 1); end = start.AddYears(1); break;
            default: start = new DateTime(now.Year, now.Month, 1); end = start.AddMonths(1); break;
        }
        if (start < b.StartDate.Date) start = b.StartDate.Date;
        if (b.EndDate.HasValue && end > b.EndDate.Value.Date.AddDays(1)) end = b.EndDate.Value.Date.AddDays(1);
        return (start, end);
    }
}
