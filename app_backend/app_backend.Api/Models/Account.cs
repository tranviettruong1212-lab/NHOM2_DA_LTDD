namespace app_backend.Api.Models;

public sealed class Account
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerUserId { get; set; }
    public Guid? HouseholdId { get; set; }

    public required string Name { get; set; }
    public AccountType Type { get; set; }
    public decimal OpeningBalance { get; set; }
    public bool IsDemo { get; set; } = true;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User? OwnerUser { get; set; }
    public Household? Household { get; set; }
}