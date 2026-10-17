using app_backend.Api.Data;
using app_backend.Api.DTOs;
using app_backend.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace app_backend.Api.Services;

public sealed class TransactionService(FinanceManagerDbContext db, HouseholdAuthorizationService householdAuth)
{
    public IQueryable<Transaction> VisibleQuery(User user, bool forSummary = false)
    {
        var uid = user.Id;
        return db.Transactions.AsNoTracking().Where(t => !t.IsDeleted && (
            t.CreatedByUserId == uid ||
            (t.HouseholdId != null && db.HouseholdMembers.Any(m =>
                m.HouseholdId == t.HouseholdId && m.UserId == uid && m.Status == MemberStatus.Active &&
                (t.Visibility == TransactionVisibility.Household ||
                 (t.Visibility == TransactionVisibility.SelectedMembers && db.TransactionShares.Any(s => s.TransactionId == t.Id && s.UserId == uid))) &&
                (forSummary || t.Type != TransactionType.Income || m.CanViewIncomeDetails || m.Role == MemberRole.Owner)))
        ));
    }

    public async Task<List<Transaction>> ListAsync(User user, DateTime? from, DateTime? to, CancellationToken ct)
    {
        var q = VisibleQuery(user).Include(t => t.Category).Include(t => t.Account).AsQueryable();
        if (from.HasValue) q = q.Where(t => t.TransactionDate >= from.Value);
        if (to.HasValue) q = q.Where(t => t.TransactionDate < to.Value);
        return await q.OrderByDescending(t => t.TransactionDate).ToListAsync(ct);
    }

    public Task<Transaction?> GetVisibleAsync(User user, Guid id, CancellationToken ct) =>
        VisibleQuery(user).Include(t => t.Category).Include(t => t.Account).SingleOrDefaultAsync(t => t.Id == id, ct);

    public async Task<(Transaction? Value, string? Error)> CreateAsync(User user, CreateTransactionRequest request, CancellationToken ct)
    {
        var validation = await ValidateRequestAsync(user, request, null, ct);
        if (validation.Error is not null) return (null, validation.Error);
        var account = validation.Account!;
        var householdId = request.HouseholdId ?? account.HouseholdId;
        if (request.Visibility != TransactionVisibility.Private && householdId is null) return (null, "household_required");

        var transaction = new Transaction {
            CreatedByUserId = user.Id, AccountId = account.Id, CategoryId = request.CategoryId,
            HouseholdId = householdId, Type = request.Type, Amount = request.Amount,
            TransactionDate = request.TransactionDate, Note = request.Note?.Trim(), Visibility = request.Visibility,
            CreatedAt = DateTime.UtcNow
        };
        var approvalNeeded = await NeedsApprovalAsync(transaction, ct);
        transaction.RequiresApproval = approvalNeeded;
        transaction.Status = approvalNeeded ? TransactionStatus.PendingApproval : TransactionStatus.Approved;
        if (approvalNeeded) db.ApprovalRequests.Add(new ApprovalRequest { TransactionId = transaction.Id, RequestedByUserId = user.Id, Status = ApprovalStatus.Pending });
        db.Transactions.Add(transaction);
        AddShares(transaction, user, request.SharedWithUserIds);
        await db.SaveChangesAsync(ct);
        return (transaction, null);
    }

    public async Task<(Transaction? Value, string? Error)> UpdateAsync(User user, Guid id, CreateTransactionRequest request, CancellationToken ct)
    {
        var transaction = await db.Transactions.SingleOrDefaultAsync(t => t.Id == id && !t.IsDeleted, ct);
        if (transaction is null) return (null, "not_found");
        if (transaction.CreatedByUserId != user.Id) return (null, "forbidden");
        if (transaction.Status == TransactionStatus.PendingApproval) return (null, "pending_approval");
        if (transaction.HouseholdId.HasValue && transaction.Visibility != TransactionVisibility.Private &&
            !await householdAuth.CanManageHouseholdAsync(transaction.HouseholdId.Value, user.Id, ct)) return (null, "shared_edit_requires_admin");
        var validation = await ValidateRequestAsync(user, request, id, ct);
        if (validation.Error is not null) return (null, validation.Error);
        var account = validation.Account!;
        transaction.AccountId = account.Id; transaction.CategoryId = request.CategoryId;
        transaction.HouseholdId = request.HouseholdId ?? account.HouseholdId; transaction.Type = request.Type;
        transaction.Amount = request.Amount; transaction.TransactionDate = request.TransactionDate;
        transaction.Note = request.Note?.Trim(); transaction.Visibility = request.Visibility; transaction.UpdatedAt = DateTime.UtcNow;
        db.TransactionShares.RemoveRange(db.TransactionShares.Where(s => s.TransactionId == id));
        if (request.Visibility != TransactionVisibility.Private && transaction.HouseholdId is null) return (null, "household_required");
        var approvalNeeded = await NeedsApprovalAsync(transaction, ct);
        transaction.RequiresApproval = approvalNeeded;
        transaction.Status = approvalNeeded ? TransactionStatus.PendingApproval : TransactionStatus.Approved;
        var approval = await db.ApprovalRequests.SingleOrDefaultAsync(a => a.TransactionId == id, ct);
        if (approvalNeeded)
        {
            if (approval is null) db.ApprovalRequests.Add(new ApprovalRequest { TransactionId = id, RequestedByUserId = user.Id, Status = ApprovalStatus.Pending });
            else { approval.Status = ApprovalStatus.Pending; approval.RequestedByUserId = user.Id; approval.ReviewedByUserId = null; approval.ReviewedAt = null; approval.ReviewNote = null; }
        }
        else if (approval is not null) { approval.Status = ApprovalStatus.Approved; approval.ReviewedByUserId = user.Id; approval.ReviewedAt = DateTime.UtcNow; }
        AddShares(transaction, user, request.SharedWithUserIds);
        await db.SaveChangesAsync(ct);
        return (transaction, null);
    }

    public async Task<string?> DeleteAsync(User user, Guid id, CancellationToken ct)
    {
        var t = await db.Transactions.SingleOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
        if (t is null) return "not_found";
        if (t.CreatedByUserId != user.Id && (!t.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(t.HouseholdId.Value, user.Id, ct))) return "forbidden";
        if (t.Status == TransactionStatus.PendingApproval) return "pending_approval";
        t.IsDeleted = true; t.UpdatedAt = DateTime.UtcNow; t.Status = TransactionStatus.Cancelled;
        await db.SaveChangesAsync(ct); return null;
    }

    private async Task<(Account? Account, string? Error)> ValidateRequestAsync(User user, CreateTransactionRequest r, Guid? transactionId, CancellationToken ct)
    {
        if (r.Amount <= 0) return (null, "invalid_amount");
        if (r.TransactionDate == default) return (null, "invalid_date");
        if (!Enum.IsDefined(r.Type) || !Enum.IsDefined(r.Visibility)) return (null, "invalid_enum");
        var account = await db.Accounts.SingleOrDefaultAsync(a => a.Id == r.AccountId && a.IsActive &&
            (a.OwnerUserId == user.Id || (a.HouseholdId != null && db.HouseholdMembers.Any(m => m.HouseholdId == a.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active))), ct);
        if (account is null) return (null, "account_not_found_or_forbidden");
        if (r.CategoryId.HasValue)
        {
            var category = await db.Categories.SingleOrDefaultAsync(c => c.Id == r.CategoryId.Value && c.IsActive, ct);
            if (category is null) return (null, "category_not_found");
            if (r.Type == TransactionType.Transfer || (r.Type == TransactionType.Income && category.Type != TransactionType.Income) || (r.Type == TransactionType.Expense && category.Type != TransactionType.Expense)) return (null, "category_type_mismatch");
        }
        var effectiveHouseholdId = r.HouseholdId ?? account.HouseholdId;
        if (effectiveHouseholdId.HasValue && await householdAuth.GetActiveMembershipAsync(effectiveHouseholdId.Value, user.Id, ct) is null)
            return (null, "household_forbidden");
        if (r.Visibility != TransactionVisibility.Private && !effectiveHouseholdId.HasValue)
            return (null, "household_required");
        if (r.Visibility == TransactionVisibility.SelectedMembers && (r.SharedWithUserIds is null || r.SharedWithUserIds.Count == 0))
            return (null, "share_recipients_required");
        if (r.Visibility != TransactionVisibility.SelectedMembers && r.SharedWithUserIds.Count > 0)
            return (null, "share_recipients_not_allowed");
        if (r.SharedWithUserIds.Distinct().Count() != r.SharedWithUserIds.Count)
            return (null, "duplicate_share_recipient");
        if (effectiveHouseholdId.HasValue)
        {
            foreach (var targetId in r.SharedWithUserIds)
                if (!await db.HouseholdMembers.AnyAsync(m => m.HouseholdId == effectiveHouseholdId.Value && m.UserId == targetId && m.Status == MemberStatus.Active, ct))
                    return (null, "share_recipient_not_member");
        }
        return (account, null);
    }

    private async Task<bool> NeedsApprovalAsync(Transaction t, CancellationToken ct)
    {
        if (t.Type != TransactionType.Expense || t.Visibility == TransactionVisibility.Private || !t.HouseholdId.HasValue) return false;
        var household = await db.Households.SingleOrDefaultAsync(h => h.Id == t.HouseholdId.Value && h.IsActive, ct);
        return household is not null && t.Amount > household.ApprovalThreshold;
    }

    private void AddShares(Transaction t, User user, IEnumerable<Guid>? ids)
    {
        if (t.Visibility != TransactionVisibility.SelectedMembers || ids is null) return;
        foreach (var id in ids.Distinct().Where(id => id != user.Id))
            db.TransactionShares.Add(new TransactionShare { TransactionId = t.Id, UserId = id, SharedByUserId = user.Id });
    }
}
