using app_backend.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace app_backend.Api.Controllers;

[Route("api/me")]
[Authorize]
public sealed class MeController(CurrentUserService currentUserService) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var user = await currentUserService.GetUserAsync(User, ct);
        return user is null ? Unauthorized() : Ok(new { user.Id, user.Email, user.DisplayName, user.CreatedAt });
    }
    public sealed record UpdateMeRequest(string DisplayName);
    [HttpPut]
    public async Task<IActionResult> Update(UpdateMeRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.DisplayName) || request.DisplayName.Trim().Length > 150) return BadRequest(new { error = "invalid_display_name" });
        var user = await currentUserService.GetUserAsync(User, ct);
        if (user is null) return Unauthorized();
        user.DisplayName = request.DisplayName.Trim();
        await currentUserService.SaveAsync(ct);
        return Ok(new { user.Id, user.Email, user.DisplayName, user.CreatedAt });
    }
}
