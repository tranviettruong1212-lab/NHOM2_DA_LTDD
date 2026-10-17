using app_backend.Api.DTOs;
using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace app_backend.Api.Controllers;

[Route("api/transactions")]
[Authorize]
public sealed class TransactionsController(TransactionService transactions, CurrentUserService currentUserService) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
    {
        if (from.HasValue && to.HasValue && from >= to) return BadRequest(new { error = "invalid_date_range" });
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var items = await transactions.ListAsync(user, from, to, ct);
        return Ok(items.Select(ToDto));
    }
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var item = await transactions.GetVisibleAsync(user, id, ct); return item is null ? NotFound() : Ok(ToDto(item));
    }
    [HttpPost]
    public async Task<IActionResult> Create(CreateTransactionRequest request, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var result = await transactions.CreateAsync(user, request, ct);
        if (result.Error is not null) return ServiceError(result.Error);
        return CreatedAtAction(nameof(Get), new { id = result.Value!.Id }, ToDto(result.Value));
    }
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, CreateTransactionRequest request, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var result = await transactions.UpdateAsync(user, id, request, ct);
        if (result.Error is not null) return ServiceError(result.Error);
        return Ok(ToDto(result.Value!));
    }
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var error = await transactions.DeleteAsync(user, id, ct); return error is null ? NoContent() : ServiceError(error);
    }
    private static object ToDto(Transaction t) => new { t.Id, t.HouseholdId, t.CreatedByUserId, t.AccountId, AccountName = t.Account?.Name, t.CategoryId, CategoryName = t.Category?.Name, t.Type, t.Amount, t.TransactionDate, t.Note, t.Visibility, t.Status, t.RequiresApproval, t.ApprovedByUserId, t.ApprovedAt, t.CreatedAt, t.UpdatedAt };
}
