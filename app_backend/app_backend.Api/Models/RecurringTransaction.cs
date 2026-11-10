namespace app_backend.Api.Models;

public sealed class RecurringTransaction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CreatedByUserId { get; set; }
    public Guid? HouseholdId { get; set; }
    public Guid AccountId { get; set; }
    public Guid? CategoryId { get; set; }

    public string Title { get; set; } = string.Empty;
    public TransactionType Type { get; set; } = TransactionType.Expense;
    public decimal Amount { get; set; }
    public RecurrenceFrequency Frequency { get; set; } = RecurrenceFrequency.Monthly;
    public DateTime StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public DateTime NextDueDate { get; set; }
    public DateTime? LastGeneratedDate { get; set; }

    public bool AutoCreate { get; set; } = true;
    public bool IsActive { get; set; } = true;
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    public User? CreatedByUser { get; set; }
    public Household? Household { get; set; }
    public Account? Account { get; set; }
    public Category? Category { get; set; }
}

