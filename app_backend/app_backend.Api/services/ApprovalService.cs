using app_backend.Api.Data;
using app_backend.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Services;

public sealed class ApprovalService(FinanceManagerDbContext db, HouseholdAuthorizationService householdAuth)
{
    public async Task<List<ApprovalRequest>> ListPendingAsync(User user, CancellationToken ct)
    {
        return await db.ApprovalRequests.AsNoTracking()
            .Include(a => a.Transaction)
                .ThenInclude(t => t!.Category)
            .Include(a => a.RequestedByUser)
            .Where(a => a.Status == ApprovalStatus.Pending && a.Transaction != null && !a.Transaction.IsDeleted && a.Transaction.HouseholdId != null &&
                db.HouseholdMembers.Any(m => m.HouseholdId == a.Transaction.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active &&
                    (m.Role == MemberRole.Owner || (m.Role == MemberRole.Admin && m.CanApproveExpenses))))
            .OrderBy(a => a.CreatedAt).ToListAsync(ct);
    }

    public async Task<(ApprovalRequest? Value, string? Error)> ReviewAsync(User reviewer, Guid requestId, bool approve, string? note, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var request = await db.ApprovalRequests.Include(a => a.Transaction).SingleOrDefaultAsync(a => a.Id == requestId, ct);
        if (request?.Transaction is null || request.Transaction.IsDeleted) return (null, "not_found");
        if (request.Status != ApprovalStatus.Pending || request.Transaction.Status != TransactionStatus.PendingApproval) return (null, "already_reviewed");
        var householdId = request.Transaction.HouseholdId;
        if (!householdId.HasValue || !await householdAuth.CanApproveExpensesAsync(householdId.Value, reviewer.Id, ct)) return (null, "forbidden");
        if (request.RequestedByUserId == reviewer.Id) return (null, "cannot_approve_own_request");
        var now = DateTime.UtcNow;
        request.Status = approve ? ApprovalStatus.Approved : ApprovalStatus.Rejected;
        request.ReviewedByUserId = reviewer.Id; request.ReviewedAt = now; request.ReviewNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
        request.Transaction.Status = approve ? TransactionStatus.Approved : TransactionStatus.Rejected;
        request.Transaction.ApprovedByUserId = approve ? reviewer.Id : null;
        request.Transaction.ApprovedAt = approve ? now : null;
        request.Transaction.UpdatedAt = now;
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        return (request, null);
    }
}
