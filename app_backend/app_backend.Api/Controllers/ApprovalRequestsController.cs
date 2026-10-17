using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace app_backend.Api.Controllers;

[Route("api/approval-requests")]
[Authorize]
public sealed class ApprovalRequestsController(ApprovalService approvals, CurrentUserService currentUserService) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var rows = await approvals.ListPendingAsync(user, ct);
        return Ok(rows.Select(a => new { a.Id, a.TransactionId, a.RequestedByUserId, a.Status, a.CreatedAt, a.Transaction!.HouseholdId, a.Transaction.Amount, a.Transaction.Type, a.Transaction.Note, a.Transaction.TransactionDate }));
    }
    public sealed record ReviewRequest(string? ReviewNote);
    [HttpPost("{id:guid}/approve")]
    public Task<IActionResult> Approve(Guid id, ReviewRequest request, CancellationToken ct) => Review(id, request, true, ct);
    [HttpPost("{id:guid}/reject")]
    public Task<IActionResult> Reject(Guid id, ReviewRequest request, CancellationToken ct) => Review(id, request, false, ct);
    private async Task<IActionResult> Review(Guid id, ReviewRequest request, bool approve, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var result = await approvals.ReviewAsync(user, id, approve, request.ReviewNote, ct);
        if (result.Error is not null) return ServiceError(result.Error);
        return Ok(new { result.Value!.Id, result.Value.Status, result.Value.ReviewedByUserId, result.Value.ReviewedAt, result.Value.ReviewNote });
    }
}
