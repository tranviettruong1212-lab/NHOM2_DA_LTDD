using app_backend.Api.Data;
using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace app_backend.Api.Controllers;

[Route("api/recurring-transactions")]
[Authorize]
public sealed class RecurringTransactionsController(
    FinanceManagerDbContext db,
    CurrentUserService currentUserService,
    HouseholdAuthorizationService householdAuth) : ApiControllerBase
{
    public sealed record CreateRecurringTransactionRequest(
        [Required, MaxLength(150)] string Title,
        decimal Amount,
        TransactionType Type,
        RecurrenceFrequency Frequency,
        DateTime StartDate,
        DateTime? EndDate,
        DateTime? NextDueDate,
        Guid AccountId,
        Guid? CategoryId,
        Guid? HouseholdId = null,
        bool AutoCreate = true,
        string? Note = null
    );

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] bool? activeOnly, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var today = DateTime.UtcNow.Date;
            var query = db.RecurringTransactions.AsNoTracking()
                .Include(r => r.Account)
                .Include(r => r.Category)
                .Where(r => r.CreatedByUserId == user.Id || (r.HouseholdId != null && db.HouseholdMembers.Any(m =>
                    m.HouseholdId == r.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active)));

            if (activeOnly == true)
            {
                query = query.Where(r => r.IsActive);
            }

            var items = await query.OrderBy(r => r.NextDueDate).ToListAsync(ct);

            var result = items.Select(r => ToDto(r, today));
            return Ok(result);
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var item = await db.RecurringTransactions.AsNoTracking()
                .Include(r => r.Account)
                .Include(r => r.Category)
                .SingleOrDefaultAsync(r => r.Id == id, ct);

            if (item is null) return NotFound();
            if (item.CreatedByUserId != user.Id &&
                (!item.HouseholdId.HasValue || await householdAuth.GetActiveMembershipAsync(item.HouseholdId.Value, user.Id, ct) is null))
            {
                return Forbid();
            }

            return Ok(ToDto(item, DateTime.UtcNow.Date));
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateRecurringTransactionRequest req, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        var error = await ValidateRequestAsync(user, req, ct);
        if (error is not null) return ServiceError(error);

        try
        {
            var nextDue = req.NextDueDate?.Date ?? req.StartDate.Date;
            if (nextDue < req.StartDate.Date) nextDue = req.StartDate.Date;

            var recurring = new RecurringTransaction
            {
                CreatedByUserId = user.Id,
                HouseholdId = req.HouseholdId,
                AccountId = req.AccountId,
                CategoryId = req.CategoryId,
                Title = req.Title.Trim(),
                Type = req.Type,
                Amount = req.Amount,
                Frequency = req.Frequency,
                StartDate = req.StartDate.Date,
                EndDate = req.EndDate?.Date,
                NextDueDate = nextDue,
                AutoCreate = req.AutoCreate,
                IsActive = true,
                Note = string.IsNullOrWhiteSpace(req.Note) ? null : req.Note.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            db.RecurringTransactions.Add(recurring);
            await db.SaveChangesAsync(ct);

            // Tải lại với relations
            var created = await db.RecurringTransactions.AsNoTracking()
                .Include(r => r.Account)
                .Include(r => r.Category)
                .SingleAsync(r => r.Id == recurring.Id, ct);

            return Created($"/api/recurring-transactions/{recurring.Id}", ToDto(created, DateTime.UtcNow.Date));
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, CreateRecurringTransactionRequest req, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var recurring = await db.RecurringTransactions.SingleOrDefaultAsync(r => r.Id == id, ct);
            if (recurring is null) return NotFound();

            if (recurring.CreatedByUserId != user.Id &&
                (!recurring.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(recurring.HouseholdId.Value, user.Id, ct)))
            {
                return Forbid();
            }

            var error = await ValidateRequestAsync(user, req, ct);
            if (error is not null) return ServiceError(error);

            recurring.Title = req.Title.Trim();
            recurring.Amount = req.Amount;
            recurring.Type = req.Type;
            recurring.Frequency = req.Frequency;
            recurring.StartDate = req.StartDate.Date;
            recurring.EndDate = req.EndDate?.Date;
            recurring.AccountId = req.AccountId;
            recurring.CategoryId = req.CategoryId;
            recurring.HouseholdId = req.HouseholdId;
            recurring.AutoCreate = req.AutoCreate;
            recurring.Note = string.IsNullOrWhiteSpace(req.Note) ? null : req.Note.Trim();
            recurring.UpdatedAt = DateTime.UtcNow;

            if (req.NextDueDate.HasValue)
            {
                recurring.NextDueDate = req.NextDueDate.Value.Date;
            }

            await db.SaveChangesAsync(ct);

            var updated = await db.RecurringTransactions.AsNoTracking()
                .Include(r => r.Account)
                .Include(r => r.Category)
                .SingleAsync(r => r.Id == id, ct);

            return Ok(ToDto(updated, DateTime.UtcNow.Date));
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var recurring = await db.RecurringTransactions.SingleOrDefaultAsync(r => r.Id == id, ct);
            if (recurring is null) return NotFound();

            if (recurring.CreatedByUserId != user.Id &&
                (!recurring.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(recurring.HouseholdId.Value, user.Id, ct)))
            {
                return Forbid();
            }

            db.RecurringTransactions.Remove(recurring);
            await db.SaveChangesAsync(ct);
            return NoContent();
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpPost("{id:guid}/toggle")]
    public async Task<IActionResult> Toggle(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var recurring = await db.RecurringTransactions
                .Include(r => r.Account)
                .Include(r => r.Category)
                .SingleOrDefaultAsync(r => r.Id == id, ct);
            if (recurring is null) return NotFound();

            if (recurring.CreatedByUserId != user.Id &&
                (!recurring.HouseholdId.HasValue || !await householdAuth.CanManageHouseholdAsync(recurring.HouseholdId.Value, user.Id, ct)))
            {
                return Forbid();
            }

            recurring.IsActive = !recurring.IsActive;
            recurring.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            return Ok(ToDto(recurring, DateTime.UtcNow.Date));
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpPost("{id:guid}/execute")]
    public async Task<IActionResult> Execute(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var recurring = await db.RecurringTransactions
                .Include(r => r.Account)
                .Include(r => r.Category)
                .SingleOrDefaultAsync(r => r.Id == id, ct);
            if (recurring is null) return NotFound();

            if (recurring.CreatedByUserId != user.Id &&
                (!recurring.HouseholdId.HasValue || await householdAuth.GetActiveMembershipAsync(recurring.HouseholdId.Value, user.Id, ct) is null))
            {
                return Forbid();
            }

            var today = DateTime.UtcNow.Date;
            var transactionDate = recurring.NextDueDate <= today ? recurring.NextDueDate : today;

            var tx = GenerateTransaction(recurring, user.Id, transactionDate);
            db.Transactions.Add(tx);

            // Cập nhật kỳ hạn tiếp theo
            AdvanceNextDueDate(recurring);
            recurring.LastGeneratedDate = today;
            recurring.UpdatedAt = DateTime.UtcNow;

            // Nếu thuộc hộ gia đình, thêm thông báo
            if (recurring.HouseholdId.HasValue)
            {
                db.HouseholdNotifications.Add(new HouseholdNotification
                {
                    HouseholdId = recurring.HouseholdId.Value,
                    RecipientUserId = user.Id,
                    Title = "Giao dịch định kỳ đã được ghi nhận",
                    Message = $"Khoản \"{recurring.Title}\" ({recurring.Amount:N0} đ) đã được ghi nhận vào sổ giao dịch.",
                    CreatedAt = DateTime.UtcNow
                });
            }

            await db.SaveChangesAsync(ct);

            return Ok(new
            {
                message = "executed_successfully",
                transactionId = tx.Id,
                recurring = ToDto(recurring, today)
            });
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    [HttpPost("process-due")]
    public async Task<IActionResult> ProcessDue(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();

        try
        {
            var today = DateTime.UtcNow.Date;
            var dueItems = await db.RecurringTransactions
                .Include(r => r.Account)
                .Include(r => r.Category)
                .Where(r => r.IsActive && r.AutoCreate && r.NextDueDate <= today &&
                    (r.CreatedByUserId == user.Id || (r.HouseholdId != null && db.HouseholdMembers.Any(m =>
                        m.HouseholdId == r.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active))))
                .ToListAsync(ct);

            var createdTransactions = new List<object>();

            foreach (var item in dueItems)
            {
                // Tránh tạo lặp vô tận nếu ngày quá cũ: tạo cho kỳ hiện tại
                var txDate = item.NextDueDate;
                var tx = GenerateTransaction(item, user.Id, txDate);
                db.Transactions.Add(tx);

                AdvanceNextDueDate(item);
                item.LastGeneratedDate = today;
                item.UpdatedAt = DateTime.UtcNow;

                createdTransactions.Add(new
                {
                    item.Id,
                    item.Title,
                    item.Amount,
                    TransactionId = tx.Id,
                    NextDueDate = item.NextDueDate
                });
            }

            if (dueItems.Count > 0)
            {
                await db.SaveChangesAsync(ct);
            }

            return Ok(new
            {
                processedCount = dueItems.Count,
                items = createdTransactions
            });
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return SchemaMissing();
        }
    }

    private static Transaction GenerateTransaction(RecurringTransaction r, Guid userId, DateTime txDate)
    {
        var note = string.IsNullOrWhiteSpace(r.Note)
            ? $"[Định kỳ] {r.Title}"
            : $"[Định kỳ] {r.Title}\n{r.Note}";

        return new Transaction
        {
            CreatedByUserId = userId,
            HouseholdId = r.HouseholdId,
            AccountId = r.AccountId,
            CategoryId = r.CategoryId,
            Type = r.Type,
            Amount = r.Amount,
            TransactionDate = txDate,
            Note = note,
            Visibility = r.HouseholdId.HasValue ? TransactionVisibility.Household : TransactionVisibility.Private,
            Status = TransactionStatus.Approved,
            RequiresApproval = false,
            CreatedAt = DateTime.UtcNow
        };
    }

    private static void AdvanceNextDueDate(RecurringTransaction r)
    {
        var current = r.NextDueDate;
        DateTime next = r.Frequency switch
        {
            RecurrenceFrequency.Daily => current.AddDays(1),
            RecurrenceFrequency.Weekly => current.AddDays(7),
            RecurrenceFrequency.Monthly => current.AddMonths(1),
            RecurrenceFrequency.Yearly => current.AddYears(1),
            _ => current.AddMonths(1)
        };

        r.NextDueDate = next;
        if (r.EndDate.HasValue && r.NextDueDate > r.EndDate.Value)
        {
            r.IsActive = false; // Đã hoàn thành hết chu kỳ
        }
    }

    private async Task<string?> ValidateRequestAsync(User user, CreateRecurringTransactionRequest req, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.Title) || req.Title.Trim().Length > 150)
            return "invalid_title";

        if (req.Amount <= 0)
            return "invalid_amount";

        if (req.Type != TransactionType.Expense && req.Type != TransactionType.Income)
            return "invalid_transaction_type";

        if (!Enum.IsDefined(req.Frequency))
            return "invalid_frequency";

        if (req.StartDate == default)
            return "invalid_start_date";

        if (req.EndDate.HasValue && req.EndDate.Value.Date < req.StartDate.Date)
            return "invalid_end_date";

        var account = await db.Accounts.SingleOrDefaultAsync(a => a.Id == req.AccountId && a.IsActive &&
            (a.OwnerUserId == user.Id || (a.HouseholdId != null && db.HouseholdMembers.Any(m =>
                m.HouseholdId == a.HouseholdId && m.UserId == user.Id && m.Status == MemberStatus.Active))), ct);

        if (account is null)
            return "account_not_found_or_forbidden";

        if (req.CategoryId.HasValue)
        {
            var category = await db.Categories.SingleOrDefaultAsync(c => c.Id == req.CategoryId.Value && c.IsActive, ct);
            if (category is null) return "category_not_found";
            if ((req.Type == TransactionType.Income && category.Type != TransactionType.Income) ||
                (req.Type == TransactionType.Expense && category.Type != TransactionType.Expense))
                return "category_type_mismatch";
        }

        if (req.HouseholdId.HasValue && await householdAuth.GetActiveMembershipAsync(req.HouseholdId.Value, user.Id, ct) is null)
            return "household_forbidden";

        return null;
    }

    private static object ToDto(RecurringTransaction r, DateTime today)
    {
        var isDue = r.IsActive && r.NextDueDate.Date <= today;
        var daysUntilDue = (r.NextDueDate.Date - today).Days;

        var frequencyName = r.Frequency switch
        {
            RecurrenceFrequency.Daily => "Hàng ngày",
            RecurrenceFrequency.Weekly => "Hàng tuần",
            RecurrenceFrequency.Monthly => "Hàng tháng",
            RecurrenceFrequency.Yearly => "Hàng năm",
            _ => "Hàng tháng"
        };

        return new
        {
            r.Id,
            r.Title,
            r.Amount,
            r.Type,
            r.Frequency,
            FrequencyName = frequencyName,
            r.StartDate,
            r.EndDate,
            r.NextDueDate,
            r.LastGeneratedDate,
            r.AutoCreate,
            r.IsActive,
            r.Note,
            r.AccountId,
            AccountName = r.Account?.Name ?? "Tài khoản",
            r.CategoryId,
            CategoryName = r.Category?.Name ?? "Khác",
            r.HouseholdId,
            IsDue = isDue,
            DaysUntilDue = daysUntilDue,
            r.CreatedAt,
            r.UpdatedAt
        };
    }

    private ObjectResult SchemaMissing() =>
        StatusCode(StatusCodes.Status503ServiceUnavailable, new
        {
            error = "recurring_transactions_schema_missing"
        });
}
