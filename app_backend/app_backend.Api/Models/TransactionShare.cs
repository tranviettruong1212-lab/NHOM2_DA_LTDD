
namespace app_backend.Api.Models;

public sealed class TransactionShare
{
    public Guid TransactionId { get; set; }

    public Guid UserId { get; set; }

    public Guid SharedByUserId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Transaction? Transaction { get; set; }

    public User? User { get; set; }

    public User? SharedByUser { get; set; }
}
