namespace app_backend.Api.Models;

public sealed class Transaction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? HouseholdId { get; set; }
    public Guid CreatedByUserId { get; set; }
    public Guid AccountId { get; set; }
    public Guid? CategoryId { get; set; }

    public TransactionType Type { get; set; }
    public decimal Amount { get; set; }
    public DateTime TransactionDate { get; set; }
    public string? Note { get; set; }

    public TransactionVisibility Visibility { get; set; }
        = TransactionVisibility.Private;

    public TransactionStatus Status { get; set; }
        = TransactionStatus.Draft;

    public bool RequiresApproval { get; set; }
    public Guid? ApprovedByUserId { get; set; }
    public DateTime? ApprovedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }

    // EF Core maps this to SQL Server rowversion.
    public byte[] RowVersion { get; set; } = [];

    public Household? Household { get; set; }
    public User? CreatedByUser { get; set; }
    public Account? Account { get; set; }
    public Category? Category { get; set; }
}