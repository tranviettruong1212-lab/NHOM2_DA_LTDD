using System.ComponentModel.DataAnnotations;
using app_backend.Api.Models;

namespace app_backend.Api.DTOs;

public class CreateTransactionRequest
{
    [Required] public Guid AccountId { get; init; }
    public Guid? HouseholdId { get; init; }
    public Guid? CategoryId { get; init; }
    [Required] public TransactionType Type { get; init; }
    [Range(
        typeof(decimal),
        "0.01",
        "79228162514264337593543950335",
        ParseLimitsInInvariantCulture = true,
        ConvertValueInInvariantCulture = true,
        ErrorMessage = "Số tiền phải lớn hơn hoặc bằng 0.01."
    )]
    public decimal Amount { get; init; }
    public DateTime TransactionDate { get; init; }
    [MaxLength(1000)] public string? Note { get; init; }
    public TransactionVisibility Visibility { get; init; } = TransactionVisibility.Private;
    public List<Guid> SharedWithUserIds { get; init; } = [];
}
