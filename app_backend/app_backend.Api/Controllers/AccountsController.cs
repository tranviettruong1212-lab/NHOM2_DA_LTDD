using app_backend.Api.Data;
using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace app_backend.Api.Controllers;

[Route("api/accounts")]
[Authorize]
public sealed class AccountsController(FinanceManagerDbContext db, CurrentUserService currentUserService, HouseholdAuthorizationService householdAuth) : ApiControllerBase
{
    public sealed record CreateAccountRequest([Required, MaxLength(100)] string Name, AccountType Type, decimal OpeningBalance = 0, Guid? HouseholdId = null, bool IsDemo = true);
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var items = await db.Accounts.AsNoTracking().Where(a => a.IsActive && (a.OwnerUserId == user.Id || (a.HouseholdId != null && db.HouseholdMembers.Any(m => m.HouseholdId == a.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active))))
            .OrderBy(a => a.Name).Select(a => new { a.Id, a.Name, a.Type, a.OpeningBalance, a.IsDemo, a.HouseholdId, a.CreatedAt }).ToListAsync(ct);
        return Ok(items);
    }
    [HttpPost]
    public async Task<IActionResult> Create(CreateAccountRequest request, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length > 100 || request.OpeningBalance < 0 || !Enum.IsDefined(request.Type)) return BadRequest(new { error = "invalid_account" });
        if (request.HouseholdId.HasValue && await householdAuth.GetActiveMembershipAsync(request.HouseholdId.Value, user.Id, ct) is null) return Forbid();
        var account = new Account { OwnerUserId = user.Id, HouseholdId = request.HouseholdId, Name = request.Name.Trim(), Type = request.Type, OpeningBalance = request.OpeningBalance, IsDemo = true };
        db.Accounts.Add(account); await db.SaveChangesAsync(ct);
        return Created($"/api/accounts/{account.Id}", new { account.Id, account.Name, account.Type, account.OpeningBalance, account.IsDemo, account.HouseholdId, account.CreatedAt });
    }
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var account = await db.Accounts.SingleOrDefaultAsync(a => a.Id == id && a.IsActive, ct); if (account is null) return NotFound();
        if (account.OwnerUserId != user.Id && (!account.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(account.HouseholdId.Value, user.Id, ct))) return Forbid();
        if (await db.Transactions.AnyAsync(t => t.AccountId == id && !t.IsDeleted, ct)) return Conflict(new { error = "account_has_transactions" });
        account.IsActive = false; await db.SaveChangesAsync(ct); return NoContent();
    }
}
