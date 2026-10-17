namespace app_backend.Api.Models;

public sealed class Household
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Name { get; set; }
    public Guid CreatedByUserId { get; set; }
    public decimal ApprovalThreshold { get; set; } = 1_000_000m;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;

    public User? CreatedByUser { get; set; }
    public ICollection<HouseholdMember> Members { get; set; } = [];
}