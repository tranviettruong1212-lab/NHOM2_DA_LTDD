
namespace app_backend.Api.Models;

public sealed class ApprovalRequest
{
    public Guid Id { get; set; }

    public Guid TransactionId { get; set; }

    public Guid RequestedByUserId { get; set; }

    public Guid? ReviewedByUserId { get; set; }

    public ApprovalStatus Status { get; set; }
        = ApprovalStatus.Pending;

    public string? ReviewNote { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? ReviewedAt { get; set; }

    public Transaction? Transaction { get; set; }

    public User? RequestedByUser { get; set; }

    public User? ReviewedByUser { get; set; }
}
