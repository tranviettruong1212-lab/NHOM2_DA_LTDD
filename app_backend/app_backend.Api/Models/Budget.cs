
namespace app_backend.Api.Models;

public sealed class Budget
{
    public Guid Id { get; set; }

    public Guid? HouseholdId { get; set; }

    public Guid CreatedByUserId { get; set; }

    public Guid? CategoryId { get; set; }

    public required string Name { get; set; }

    public decimal LimitAmount { get; set; }

    public BudgetPeriod Period { get; set; }

    public BudgetMode Mode { get; set; }

    public BudgetPriority Priority { get; set; }
        = BudgetPriority.Normal;

    public DateTime StartDate { get; set; }

    public DateTime? EndDate { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Household? Household { get; set; }

    public User? CreatedByUser { get; set; }

    public Category? Category { get; set; }
}
