namespace app_backend.Api.Models;

public sealed class HouseholdNotification
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid HouseholdId { get; set; }
    public Guid RecipientUserId { get; set; }
    public required string Title { get; set; }
    public required string Message { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; set; }

    public Household? Household { get; set; }
    public User? RecipientUser { get; set; }
}
