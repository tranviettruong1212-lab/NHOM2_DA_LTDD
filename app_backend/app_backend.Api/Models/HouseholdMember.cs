namespace app_backend.Api.Models;

public sealed class HouseholdMember
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid HouseholdId { get; set; }
    public Guid UserId { get; set; }

    public MemberRole Role { get; set; } = MemberRole.Member;
    public MemberStatus Status { get; set; } = MemberStatus.Active;

    public bool CanViewIncomeDetails { get; set; }
    public bool CanApproveExpenses { get; set; }

    public DateTime? JoinedAt { get; set; }

    public Household? Household { get; set; }
    public User? User { get; set; }
}