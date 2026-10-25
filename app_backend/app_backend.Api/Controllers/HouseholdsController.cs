using app_backend.Api.Data;
using app_backend.Api.Models;
using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using System.ComponentModel.DataAnnotations;

namespace app_backend.Api.Controllers;

[Route("api/households")]
[Authorize]
public sealed class HouseholdsController(FinanceManagerDbContext db, CurrentUserService currentUserService, HouseholdAuthorizationService householdAuth) : ApiControllerBase
{
    public sealed record CreateHouseholdRequest([Required, MaxLength(150)] string Name, decimal ApprovalThreshold = 1000000m);
    public sealed record AddMemberRequest([Required, EmailAddress] string Email, MemberRole Role = MemberRole.Member, bool CanViewIncomeDetails = false, bool CanApproveExpenses = false);

    [HttpGet("notifications")]
    public async Task<IActionResult> Notifications(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        try
        {
            var notifications = await db.HouseholdNotifications.AsNoTracking()
                .Where(n => n.RecipientUserId == user.Id)
                .OrderByDescending(n => n.CreatedAt)
                .Select(n => new { n.Id, n.HouseholdId, n.Title, n.Message, n.CreatedAt, n.ReadAt })
                .ToListAsync(ct);
            return Ok(notifications);
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return NotificationSchemaMissing();
        }
    }

    [HttpPost("notifications/{notificationId:guid}/read")]
    public async Task<IActionResult> MarkNotificationRead(Guid notificationId, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        try
        {
            var notification = await db.HouseholdNotifications
                .SingleOrDefaultAsync(n => n.Id == notificationId && n.RecipientUserId == user.Id, ct);
            if (notification is null) return NotFound();
            notification.ReadAt ??= DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            return NoContent();
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return NotificationSchemaMissing();
        }
    }

    [HttpGet("mine")]
    public async Task<IActionResult> Mine(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var result = await db.HouseholdMembers.AsNoTracking().Where(m => m.UserId == user.Id && m.Status == MemberStatus.Active && m.Household!.IsActive).Select(m => new { m.HouseholdId, m.Role, m.CanViewIncomeDetails, m.CanApproveExpenses, HouseholdName = m.Household!.Name, m.Household!.ApprovalThreshold }).FirstOrDefaultAsync(ct);
        return Ok(result);
    }
    [HttpPost]
    public async Task<IActionResult> Create(CreateHouseholdRequest r, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Trim().Length > 150 || r.ApprovalThreshold < 0) return BadRequest(new { error = "invalid_household" });
        if (await db.HouseholdMembers.AnyAsync(m => m.UserId == user.Id && m.Status == MemberStatus.Active, ct)) return Conflict(new { error = "already_in_household" });
        var h = new Household { Name = r.Name.Trim(), CreatedByUserId = user.Id, ApprovalThreshold = r.ApprovalThreshold };
        db.Households.Add(h); db.HouseholdMembers.Add(new HouseholdMember { HouseholdId = h.Id, UserId = user.Id, Role = MemberRole.Owner, Status = MemberStatus.Active, CanViewIncomeDetails = true, CanApproveExpenses = true, JoinedAt = DateTime.UtcNow });
        await db.SaveChangesAsync(ct); return Created($"/api/households/{h.Id}", new { h.Id, h.Name, h.ApprovalThreshold, h.CreatedAt });
    }
    [HttpGet("{id:guid}/members")]
    public async Task<IActionResult> Members(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        if (await householdAuth.GetActiveMembershipAsync(id, user.Id, ct) is null) return Forbid();
        var list = await db.HouseholdMembers.AsNoTracking().Where(m => m.HouseholdId == id && m.Status == MemberStatus.Active).Select(m => new { m.Id, m.UserId, m.User!.DisplayName, m.User.Email, m.Role, m.CanViewIncomeDetails, m.CanApproveExpenses, m.JoinedAt }).ToListAsync(ct);
        return Ok(list);
    }
    [HttpPost("{id:guid}/members")]
    public async Task<IActionResult> AddMember(Guid id, AddMemberRequest r, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        if (!await householdAuth.CanManageHouseholdAsync(id, user.Id, ct)) return Forbid();
        if (r.Role == MemberRole.Owner || !Enum.IsDefined(r.Role)) return BadRequest(new { error = "invalid_member_role" });
        var target = await db.Users.SingleOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == r.Email.Trim().ToLower(), ct);
        if (target is null) return NotFound(new { error = "user_not_registered" });
        if (await db.HouseholdMembers.AnyAsync(m => m.UserId == target.Id && m.Status == MemberStatus.Active, ct)) return Conflict(new { error = "user_already_in_household" });
        var existing = await db.HouseholdMembers.SingleOrDefaultAsync(m => m.HouseholdId == id && m.UserId == target.Id, ct);
        if (existing is not null) { existing.Role = r.Role; existing.Status = MemberStatus.Active; existing.CanViewIncomeDetails = r.CanViewIncomeDetails; existing.CanApproveExpenses = r.CanApproveExpenses; existing.JoinedAt = DateTime.UtcNow; }
        else db.HouseholdMembers.Add(new HouseholdMember { HouseholdId = id, UserId = target.Id, Role = r.Role, Status = MemberStatus.Active, CanViewIncomeDetails = r.CanViewIncomeDetails, CanApproveExpenses = r.CanApproveExpenses, JoinedAt = DateTime.UtcNow });
        await db.SaveChangesAsync(ct); return Ok(new { target.Id, target.DisplayName, target.Email, Role = r.Role });
    }
    [HttpDelete("{id:guid}/members/{userId:guid}")]
    public async Task<IActionResult> RemoveMember(Guid id, Guid userId, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        if (!await householdAuth.CanManageHouseholdAsync(id, user.Id, ct)) return Forbid();
        var member = await db.HouseholdMembers.SingleOrDefaultAsync(m => m.HouseholdId == id && m.UserId == userId && m.Status == MemberStatus.Active, ct);
        if (member is null) return NotFound(); if (member.Role == MemberRole.Owner) return Conflict(new { error = "cannot_remove_owner" });
        member.Status = MemberStatus.Left; await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct); if (user is null) return Unauthorized();
        var ownerMembership = await householdAuth.GetActiveMembershipAsync(id, user.Id, ct);
        if (ownerMembership is null || ownerMembership.Role != MemberRole.Owner) return Forbid();

        var household = await db.Households.SingleOrDefaultAsync(h => h.Id == id && h.IsActive, ct);
        if (household is null) return NotFound();

        var activeMembers = await db.HouseholdMembers
            .Where(m => m.HouseholdId == id && m.Status == MemberStatus.Active)
            .ToListAsync(ct);
        var cancelledAt = DateTime.UtcNow;
        foreach (var member in activeMembers)
        {
            member.Status = MemberStatus.Left;
            if (member.UserId == user.Id) continue;
            db.HouseholdNotifications.Add(new HouseholdNotification
            {
                HouseholdId = id,
                RecipientUserId = member.UserId,
                Title = "Nhóm gia đình đã được hủy",
                Message = $"Chủ nhóm đã hủy nhóm \"{household.Name}\". Lịch sử giao dịch và ngân sách được giữ lại.",
                CreatedAt = cancelledAt
            });
        }

        household.IsActive = false;
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            return NotificationSchemaMissing();
        }
        return NoContent();
    }

    private ObjectResult NotificationSchemaMissing() =>
        StatusCode(StatusCodes.Status503ServiceUnavailable, new
        {
            error = "household_notifications_schema_missing"
        });
}
