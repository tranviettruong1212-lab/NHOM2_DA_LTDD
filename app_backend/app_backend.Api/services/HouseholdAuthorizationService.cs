using app_backend.Api.Data;
using app_backend.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Services;

public sealed class HouseholdAuthorizationService(FinanceManagerDbContext db)
{
    public Task<HouseholdMember?> GetActiveMembershipAsync(Guid householdId, Guid userId, CancellationToken ct = default) =>
        db.HouseholdMembers.SingleOrDefaultAsync(m => m.HouseholdId == householdId && m.UserId == userId && m.Status == MemberStatus.Active, ct);

    public async Task<bool> CanApproveExpensesAsync(Guid householdId, Guid userId, CancellationToken ct = default)
    {
        var m = await GetActiveMembershipAsync(householdId, userId, ct);
        return m is not null && (m.Role == MemberRole.Owner || (m.Role == MemberRole.Admin && m.CanApproveExpenses));
    }

    public async Task<bool> CanViewIncomeDetailsAsync(Guid householdId, Guid userId, CancellationToken ct = default)
    {
        var m = await GetActiveMembershipAsync(householdId, userId, ct);
        return m?.CanViewIncomeDetails == true || m?.Role == MemberRole.Owner;
    }

    public async Task<bool> CanManageHouseholdAsync(Guid householdId, Guid userId, CancellationToken ct = default)
    {
        var m = await GetActiveMembershipAsync(householdId, userId, ct);
        return m is not null && (m.Role == MemberRole.Owner || m.Role == MemberRole.Admin);
    }
}
