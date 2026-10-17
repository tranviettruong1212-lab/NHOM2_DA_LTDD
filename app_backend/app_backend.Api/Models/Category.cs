namespace app_backend.Api.Models;

public sealed class Category
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Name { get; set; }
    public TransactionType Type { get; set; }
    public bool IsSystem { get; set; }
    public bool IsActive { get; set; } = true;
}
